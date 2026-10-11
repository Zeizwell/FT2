#!/usr/bin/perl
# =========================================================================
# maxYMiser (Atari ST, gwEm) -> текст: песня, ордер, паттерны, инструменты, последовательности.
# Вход: файл .mys (песня) и/или .myv (голоса), или SNDH, выгруженный из maxYMiser (там они лежат
# сырыми файлами: плеер, 3 смещения, .myv, .mys). ICE!-упакованный SNDH пока не распаковываем.
# Формат - по исходнику плеера автора: github.com/gwEm303/maxYMiser_replay (replay.s/trakdata.s,
# replay.s/sndh.s: gen_patterntab, parsetracker, parsefxcolumn).
#   perl mym_dump.pl файл [файл2]  > вывод.txt
# =========================================================================
use strict;
use warnings;

my %eff = (                         # эффекты паттерна: буква -> что (parsefxcolumn)
    '1' => 'portamento flags', '2' => 'arpeggio flags', '3' => 'vibrato flags',
    '4' => 'transpose flags',  '5' => 'fix freq flags', '6' => 'fix detune flags',
    '7' => 'PWM slide',        '8' => 'PWM seq',        '9' => 'pulse width',
    'A' => 'arpeggio seq',     'B' => 'pattern break',  'C' => 'buzzer start sync',
    'D' => 'detune coarse',    'E' => 'detune fine',    'F' => 'fix freq seq',
    'G' => 'digi sample',      'H' => 'pitch slide',    'I' => 'timer seq',
    'L' => 'volume seq',       'M' => 'mixer seq',      'N' => 'noise seq',
    'O' => 'noise transpose',  'P' => 'portamento',     'Q' => 'sequence speed',
    'R' => 'digi rate',        'S' => 'song speed',     'T' => 'transpose',
    'U' => 'microwire',        'V' => 'vibrato seq',    'W' => 'buzzer wave',
    'X' => 'extra arpeggio',   'Y' => 'dynamic timer',  'Z' => 'demo sync',
);
my @nn = ('C-','C#','D-','D#','E-','F-','F#','G-','G#','A-','A#','B-');

# нота паттерна: 0 - пусто, 1 - off, n - индекс таблицы частот (24 = C-1, полутон на шаг)
sub note {
    my $n = shift;
    return '---' if $n == 0;
    return 'OFF' if $n == 1;
    my $o = int($n / 12) - 1;
    return $nn[$n % 12] . ($o < 0 ? '?' : $o);
}

my ($mys, $myv);
for my $f (@ARGV) {
    open my $fh, '<:raw', $f or die "$f: $!";
    local $/; my $d = <$fh>; close $fh;
    die "$f: ICE!-упакован - сначала распаковать\n" if substr($d, 0, 4) eq 'ICE!';
    if ($d =~ /MYM.TRAK/g) {        # песня: тег, дальше до конца (в SNDH - до конца файла)
        $mys = substr($d, pos($d) - 8);
    }
    pos($d) = undef;               # голоса в SNDH - раньше песни: искать с начала
    if ($d =~ /MYM.INST/g) {        # голоса: 32 байта смещений сэмплов перед тегом
        my $p = pos($d) - 8 - 32;
        $myv = substr($d, $p < 0 ? 0 : $p);
    }
    die "$f: нет тегов MYM?TRAK / MYM?INST - не maxYMiser?\n" unless $mys || $myv;
}

if ($mys) { dump_song($mys) }
if ($myv) { dump_voices($myv) }

sub b { my ($s, $o) = @_; return $o < length($s) ? ord(substr($s, $o, 1)) : 0 }

sub dump_song {
    my $s = shift;
    my $t = 8;                      # данные трекера - за тегом
    my $speed = b($s, $t + 13);
    my $tc = b($s, $t + 14);
    my $len = b($s, $t + 64 + 1024);
    my $rep = b($s, $t + 64 + 1025);
    print "=== SONG\n";
    printf "length %d  repeat %d  speed %d  timer C %d Hz\n\n", $len, $rep, $speed, $tc;
    print "=== ORDER (pos: track1 track2 track3 track4)\n";
    my %used;
    for my $p (0 .. ($len ? $len - 1 : 0)) {
        my @pt = map { b($s, $t + 64 + $p * 4 + $_) } 0 .. 3;
        printf "%02X: %s\n", $p, join(' ', map { sprintf '%02X', $_ } @pt);
        $used{$_} = 1 for grep { $_ < 0xF0 } @pt;
    }
    print "\n";
    # паттерны подряд с t+1090: строки по 8 байт, байт 7 - сколько пустых строк дальше, 64 строки
    my @pat;
    my $o = $t + 1090;
    while ($o + 8 <= length($s)) {
        last if substr($s, $o, 4) eq 'MYM' || substr($s, $o, 3) eq 'MYM';
        my (@rows, $r);
        $r = 0;
        while ($r < 64 && $o + 8 <= length($s)) {
            my @l = map { b($s, $o + $_) } 0 .. 7;
            $rows[$r] = [@l];
            $r += 1 + $l[7];
            $o += 8;
        }
        push @pat, \@rows;
    }
    print "=== PATTERNS (", scalar(@pat), " in file; used by order: ",
          join(' ', map { sprintf '%02X', $_ } sort { $a <=> $b } keys %used), ")\n";
    for my $n (sort { $a <=> $b } keys %used) {
        next unless $pat[$n];
        printf "\n--- pattern %02X\n", $n;
        for my $r (0 .. 63) {
            my $l = $pat[$n][$r] or next;
            my ($no, $in, $vo, $f1, $p1, $f2, $p2) = @$l;
            my $fx = '';
            for ([$f1, $p1], [$f2, $p2]) {
                my ($c, $v) = @$_;
                next unless $c;
                my $ch = chr($c);
                $fx .= sprintf '  %s%02X (%s)', $ch, $v, $eff{$ch} // '?';
            }
            printf "%02X  %s %s %s%s\n", $r, note($no), $in ? sprintf('%02X', $in) : '..',
                $vo ? sprintf('%X', $vo & 15) : '.', $fx;
        }
    }
    print "\n";
}

sub dump_voices {
    my $v = shift;
    my $i0 = 32 + 8;                # смещения сэмплов, тег
    print "=== INSTRUMENTS\n";
    my %seq;
    my @sn = qw(volume arpeggio vibrato mixer noise fixfreq timerwave PWM);
    for my $k (0 .. 31) {
        my $o = $i0 + $k * 64;
        last if $o + 64 > length($v);
        my $name = substr($v, $o, 16); $name =~ s/\0.*//s;
        my @p = map { b($v, $o + $_) } 0 .. 63;
        next if $name eq '' && !grep { $_ } @p[16 .. 63];
        printf "\n--- instrument %02X \"%s\"\n", $k + 1, $name;
        printf "flags: porta %d arp %d vib %d transp %d fixfreq %d fixdetune %d\n", @p[16 .. 21];
        printf "seq speed %d  pulse width %d  buzzer wave %X  buzzer startsync %d  digi %d  digi rate %02X  vol %X\n",
            @p[32 .. 38];
        printf "detune coarse %d fine %d  freq resolution %d\n", @p[39 .. 41];
        print 'sequences:';
        for my $j (0 .. 7) {
            printf ' %s=%02X', $sn[$j], $p[48 + $j];
            $seq{$p[48 + $j]} = 1;
        }
        print "\n";
    }
    # последовательности: 256 по 128 байт (63 слова, длина, повтор) - за параметрами сэмплов
    my $s0 = $i0 + 32 * 64 + 32;
    print "\n=== SEQUENCES (used by instruments)\n";
    for my $n (sort { $a <=> $b } keys %seq) {
        my $o = $s0 + $n * 128;
        next if $o + 128 > length($v);
        my $len = b($v, $o + 126);
        my $rep = b($v, $o + 127);
        my @w = map { b($v, $o + 2 * $_) * 256 + b($v, $o + 2 * $_ + 1) } 0 .. ($len ? $len - 1 : 0);
        printf "%02X len %d rep %d: %s\n", $n, $len, $rep, join(' ', map { sprintf '%04X', $_ } @w);
    }
}
