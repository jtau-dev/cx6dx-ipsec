#!/usr/bin/perl
#
# Simple script to tally running iperf3 outputs.
# Pipe all iperf3 outputs to named pipes in $FIFODIR/fifo$i
#
# 
# Usage: perfsum2.pl [number of named pipe to open]
#
#        -n Number of channels
#        -s Fifo start #
#
use IO::Handle;
use Getopt::Std;
use Getopt::Long;

#getopt("n:");
$FS=0;
GetOptions( "no-offload" => \$no-offload,
            "n=i" => \$opt_n,
            "s=i" => \$FS);

my $N = ($opt_n =~ /\d+/) ? $opt_n : 1;
my @FILES=();
$|=1;

$FIFODIR="/root/ipsec/fifos/";

@fh=();
# Open named pipes into which iperf3 output is directed.
for ($i=0; $i < $N; $i++) {
    $j=$i+$FS;
    $filename="${FIFODIR}fifo$j";
#    print $filename . "\n";
    open ($fh[$i], "< $filename");
}

# Flush the fifos
for ($i=0;$i<$N;$i++) {
    $S=readline $fh[$i];
}

# Initialize some internal variables.
$low=5000;
$hi=0;
$sum=0;

while ($sum==0){
    for ($i=0;$i<$N;$i++) {
	$S= readline $fh[$i];
#	print "S=$S";
	@SP = split(' ',$S);
	$sum+=$SP[6] * (($SP[7] =~ /Gbits/) ? 1 : 0.001);
	$UNIT=$SP[7];
    }
}

sub get_CPU_util($);

$UNIT="Gbps";
if (defined($no-offload)) {
    $MAXTHRPT = 100;
} else {
    $MAXTHRPT=($N*11 > 60) ? 60 : $N*12;
}
$M_p=$sum;
$S_p=0;
$total=$sum;
$n=2;
@tmparray=();
#print "total= $total\n";
while (1) {
    $sum=0;
# Summing all iperf output    
    for ($i=0;$i<$N;$i++) {
	$S= readline $fh[$i];

	@SP = split(' ',$S);
	$sum+= $SP[6] * (($SP[7] =~ /Gbits/) ? 1 : 0.001);
	$tmparray[$i]=$SP[6];
    }
# Calculate the running variance, see [https://www.johndcook.com/blog/standard_deviation] for
# detail.
    $Mk=$M_p + ($sum - $M_p)/$n;
    $Sk=$S_p + ($sum - $M_p)*($sum - $Mk);
    $M_p=$Mk;
    $S_p=$Sk;
    $var=$Sk/($n-1);
#    print "total= $total sum=$sum\n";
    $total+=$sum;
    $avg=$total/$n;
    $n++;
    if ($sum < $low && $sum > 0) {
	$low = $sum;
    } 
    if ($sum > $hi) {
	$hi = $sum;
    }
    $cpuu = get_CPU_util("iperf3");
    printf ("Inst: %4.1F $UNIT, Avg: %4.1f $UNIT, Var: %4.1f, low: %4.1f $UNIT, high: %4.1f $UNIT, CPU:% 3.1f\n",$sum,$avg,$var,$low,$hi,$cpuu);
    if (($sum > $MAXTHRPT) && (! $no-offload)) {
	map {print $_ . " "} @tmparray;
	print "\n";
    } elsif (($sum == 0) && ($zero_cnt == 10)) {
	print "iperf3 appears to have stopped, exiting.\n";
    }
}


sub get_CPU_util ($) {
    my $name=shift;
    my $util=0;
    foreach my $line ( qx [ps -ef ] ) {
	@F=split(" ",$line);
	$util+=$F[3] if ($F[7] =~ /$name/);
    }
    return $util;
}
