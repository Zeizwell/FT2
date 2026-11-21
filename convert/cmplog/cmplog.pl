#!/usr/bin/perl
# Разбор журнала компаратора FT2 (FT2CMP.BIN, подпись FT2CMP2).
#   perl cmplog.pl FT2CMP.BIN          - файл
#   perl cmplog.pl -img wc.img         - найти FT2CMP.BIN в образе FAT32 (без таблицы разделов)
# Журнал: заголовок 64 байта, записи по 64: кадр (2), позиция, роу, чипов, разошёлся, резерв (2),
# эталон чип 1 R0..R13, эталон чип 2, наш чип 1, наш чип 2 (R13: #FF - не пишется).
# В журнале только разошедшиеся кадры и по одному совпавшему перед каждым участком.
use strict;
use warnings;

my $data;
if (@ARGV == 2 && $ARGV[0] eq '-img') {
    $data = fat_find($ARGV[1], qr/^FT2CMP(~\d+)?\.BIN$/i) or die "FT2CMP.BIN не найден в $ARGV[1]\n";
} elsif (@ARGV == 1) {
    open my $f, '<:raw', $ARGV[0] or die "$ARGV[0]: $!\n";
    local $/; $data = <$f>;
} else {
    die "perl cmplog.pl FT2CMP.BIN | -img wc.img\n";
}

# --- заголовок
my $sig = substr($data, 0, 7);
die "не журнал FT2CMP2 (подпись '$sig')\n" unless $sig eq 'FT2CMP2';
my ($frames, $diffs, $first) = unpack 'v v C', substr($data, 8, 5);
my $chips = unpack 'C', substr($data, 27, 1);
my $kind  = unpack 'C', substr($data, 28, 1);
my $n     = unpack 'v', substr($data, 30, 2);
printf "Кадров %d, разошлось %d, записей в журнале %d, чипов %d\n", $frames, $diffs, $n, $chips;

# --- записи
my @rec;
for my $i (0 .. $n - 1) {
    my $r = substr($data, 64 + $i * 64, 64);
    last if length($r) < 64;
    my ($fr, $pos, $row, $nch, $bad) = unpack 'v C C C C', $r;
    my @b = unpack 'C*', $r;
    push @rec, { fr => $fr, pos => $pos, row => $row, bad => $bad,
                 ref => [ [ @b[8 .. 21] ], [ @b[22 .. 35] ] ],
                 our => [ [ @b[36 .. 49] ], [ @b[50 .. 63] ] ] };
}
my %by_fr = map { $_->{fr} => $_ } @rec;

sub tone { my ($r, $c) = @_; ($r->[$c * 2] | $r->[$c * 2 + 1] << 8) & 0xFFF }

# Что разошлось в кадре на чипе (по правилам компаратора: только то, что звучит у эталона)
sub diffs {
    my ($ref, $our) = @_;
    my @d;
    my $mix = $ref->[7];
    my ($anyn, $anye) = (0, 0);
    for my $c (0 .. 2) {
        my $v = $ref->[8 + $c];
        my $loud = ($v & 0x10) || ($v & 0x0F);
        $anye = 1 if $v & 0x10;
        if ($loud) {
            push @d, ["tone", $c] if !($mix & (1 << $c)) && tone($ref, $c) != tone($our, $c);
            $anyn = 1 if !($mix & (8 << $c));
            push @d, ["mix", $c] if (($mix ^ $our->[7]) & (9 << $c));
        }
        push @d, ["vol", $c] if ($v & 0x1F) != ($our->[8 + $c] & 0x1F);
    }
    push @d, ["noise", -1] if $anyn && ($ref->[6] & 0x1F) != ($our->[6] & 0x1F);
    if ($anye) {
        push @d, ["envp", -1] if ($ref->[11] | $ref->[12] << 8) != ($our->[11] | $our->[12] << 8);
    }
    push @d, ["r13", -1] if $ref->[13] != $our->[13];
    return @d;
}

# --- разбор: тон, который у нас = тон эталона кадром раньше - сдвиг глиссандо на кадр
my (%cnt, @other);
for my $r (@rec) {
    next unless $r->{bad};
    my $prev = $by_fr{$r->{fr} - 1};
    for my $ch (0 .. $chips - 1) {
        for my $d (diffs($r->{ref}[$ch], $r->{our}[$ch])) {
            my ($what, $c) = @$d;
            my $kind = $what;
            if ($what eq 'tone' && $prev
                && tone($r->{our}[$ch], $c) == tone($prev->{ref}[$ch], $c)) {
                $kind = 'tone-lag1';
            }
            $cnt{$kind}++;
            next if $kind eq 'tone-lag1';
            push @other, sprintf "кадр %04X поз %02X роу %02X чип %d %s%s: эталон %s наш %s",
                $r->{fr}, $r->{pos}, $r->{row}, $ch + 1, $what,
                $c >= 0 ? " канал " . chr(65 + $c) : "",
                val($what, $r->{ref}[$ch], $c), val($what, $r->{our}[$ch], $c);
        }
    }
}

sub val {
    my ($what, $r, $c) = @_;
    return sprintf "%03X", tone($r, $c)            if $what eq 'tone';
    return sprintf "%02X", $r->[8 + $c]            if $what eq 'vol';
    return sprintf "%02X", $r->[7]                 if $what eq 'mix';
    return sprintf "%02X", $r->[6]                 if $what eq 'noise';
    return sprintf "%04X", $r->[11] | $r->[12] << 8 if $what eq 'envp';
    return sprintf "%02X", $r->[13];
}

print "\nРасхождения по видам:\n";
printf "  %-10s %d\n", $_, $cnt{$_} for sort keys %cnt;
print "  (tone-lag1 - наш тон = тон эталона кадром раньше: сдвиг глиссандо на кадр)\n";
if (@other) {
    print "\nОстальное (", scalar(@other), "):\n";
    print "  $_\n" for @other[0 .. ($#other < 199 ? $#other : 199)];
    print "  ... ещё ", @other - 200, "\n" if @other > 200;
} else {
    print "\nДругих расхождений нет.\n";
}
print "\nВ журнале не все кадры (переполнен, $n записей).\n" if $n >= 511;

# --- FAT32 без таблицы разделов: найти файл по имени во всём дереве
sub fat_find {
    my ($img, $want) = @_;
    open my $f, '<:raw', $img or die "$img: $!\n";
    my $rd = sub { my ($off, $len) = @_; seek $f, $off, 0; my $b; read $f, $b, $len; $b };
    my $bs = $rd->(0, 512);
    my ($bps, $spc, $rsv, $nfat) = unpack 'v C v C', substr($bs, 11, 6);
    my $fatsz = unpack 'V', substr($bs, 36, 4);
    my $root  = unpack 'V', substr($bs, 44, 4);
    my $fat_off  = $rsv * $bps;
    my $data_off = ($rsv + $nfat * $fatsz) * $bps;
    my $csz = $spc * $bps;
    my $chain = sub {
        my $c = shift; my @c;
        while ($c >= 2 && $c < 0x0FFFFFF8 && @c < 1_000_000) {
            push @c, $c;
            $c = unpack('V', $rd->($fat_off + $c * 4, 4)) & 0x0FFFFFFF;
        }
        @c;
    };
    my $read = sub { join '', map { $rd->($data_off + ($_ - 2) * $csz, $csz) } $chain->(shift) };
    my @dirs = ($root);
    my %seen;
    my ($best, $bsize) = (undef, 0);  # совпало несколько - самый большой
    while (my $d = shift @dirs) {
        next if $seen{$d}++;
        my $buf = $read->($d);
        for (my $i = 0; $i + 32 <= length $buf; $i += 32) {
            my $e = substr($buf, $i, 32);
            my $b0 = ord $e;
            last if $b0 == 0;
            next if $b0 == 0xE5;
            my $attr = ord substr($e, 11, 1);
            next if $attr == 0x0F;
            my $name = substr($e, 0, 8); $name =~ s/ +$//;
            my $ext  = substr($e, 8, 3); $ext =~ s/ +$//;
            my $full = $ext ne '' ? "$name.$ext" : $name;
            my $cl = unpack('v', substr($e, 26, 2)) | unpack('v', substr($e, 20, 2)) << 16;
            my $size = unpack 'V', substr($e, 28, 4);
            if ($attr & 0x10) {
                push @dirs, $cl if $name ne '.' && $name ne '..' && $cl >= 2;
            } elsif ($full =~ $want && $size > $bsize) {
                ($best, $bsize) = (substr($read->($cl), 0, $size), $size);
            }
        }
    }
    return $best;
}
