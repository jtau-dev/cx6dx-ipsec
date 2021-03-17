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
#        -d dual test.  Bidirectional (if using iperf)
#
use IO::Handle;
use Getopt::Std;
use Getopt::Long;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
                    clock_gettime clock_getres clock_nanosleep clock
                    stat );
#getopt("n:");
$FS=0;
GetOptions( "no-offload" => \$no-offload,
            "n=i" => \$opt_n,
            "s=i" => \$FS,
            "d" => \$opt_d);

my $N = ($opt_n =~ /\d+/) ? $opt_n : 1;
my @FILES=();
$|=1;

$FIFODIR=`cat config.dat | grep FIFO_DIR`;
$FIFODIR=~s/FIFO_DIR=//;
chomp($FIFODIR);

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
$low2=5000;
$hi=0;
$hi2=0;
$sum=0;
$sum2=0;

while ($sum==0){
#    for ($i=0;$i<$N;$i++) {
#	$S= readline $fh[$i];
#	print "S=$S";
#	@SP = split(' ',$S);
#	$sum+=$SP[6] * (($SP[7] =~ /Gbits/) ? 1 : 0.001);
#	$UNIT=$SP[7];
#	if ($opt_d) {
#	    $S= readline $fh[$i];
#	    @SP = split(' ',$S);
#	    $sum2+= $SP[6] * (($SP[7] =~ /Gbits/) ? 1 : 0.001);
#	    $tmparray2[$i]=$SP[6];
#	}	    
#	
#    }
# Sync up tx/rx lines
    for ($i=0;$i<$N;$i++) {
	$S= readline $fh[$i];
	@SP = split(' ',$S);
	if ($opt_d) {
	    $S2=readline $fh[$i];
	    $S3=readline $fh[$i];
#	    print "1: $S";	
#	    print "2: $S2";
#	    print "3: $S3";
	    @SP2 = split(' ',$S2);
	    @SP3 = split(' ',$S3);
	    if ($SP2[2] =~ $SP3[2]) {
		$SP[6]=$SP2[6];
		$SP2[6]=$SP3[6];
		$SP[7]=$SP2[7];
		$SP2[7]=$SP3[7];
	    } else {
		$S3=readline $fh[$i];
	    }
	    $sum2+= $SP2[6] * (($SP2[7] =~ /Gbits/) ? 1 : 0.001);
	    $tmparray2[$i]=$SP2[6];
	} 
	$sum+= $SP[6] * (($SP[7] =~ /Gbits/) ? 1 : 0.001);
	$tmparray[$i]=$SP[6];
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

$M2_p=$sum2;
$S2_p=0;
$total2=$sum2;


@tmparray=();
#print "total= $total\n";
while (1) {
    $sum=0;
    $sum2=0;
# Summing all iperf output    
    for ($i=0;$i<$N;$i++) {
	$S= readline $fh[$i];
	@SP = split(' ',$S);
	if ($opt_d) {
	    $S2=readline $fh[$i];
#	    print "1: $S";	
#	    print "2: $S2";
	    @SP2 = split(' ',$S2);
	    $sum2+= $SP2[6] * (($SP2[7] =~ /Gbits/) ? 1 : 0.001);
	    $tmparray2[$i]=$SP2[6];
	} 
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
    
    if ($opt_d) {
	$M2k=$M2_p + ($sum2 - $M2_p)/$n;
	$S2k=$S2_p + ($sum2 - $M2_p)*($sum2 - $M2k);
	$M2_p=$M2k;
	$S2_p=$S2k;
	$var2=$S2k/($n-1);
    }

#    print "total= $total sum=$sum\n";
    if ($sum < $low && $sum > 0) {
	$low = $sum;
    } elsif ($sum > $hi) {
	$hi = $sum;
    } elsif ($sum == 0) {
	$zero_count++;
	usleep (100000);
	goto end;
    }
    if ($opt_d) {
	if ($sum2 < $low2 && $sum2 > 0) {
	    $low2 = $sum2;
	} elsif ($sum2 > $hi2) {
	    $hi2 = $sum2;
	} elsif ($sum2 == 0) {
	    $zero_count2++;
	    usleep (100000);
	    goto end;
	}
    }
    
    $zero_count=0;
    $total+=$sum;
    $avg=$total/$n;
    
    if ($opt_d) {
	$zero_count2=0;    
	$total2+=$sum2;
	$avg2=$total2/$n;
    }
    
    $n++;
    $cpuu = get_CPU_util("iperf");
    printf ("1. Inst: %4.1F $UNIT, Avg: %4.1f $UNIT, Var: %4.1f, low: %4.1f $UNIT, high: %4.1f $UNIT, CPU:% 3.1f\n",$sum,$avg,$var,$low,$hi,$cpuu);
    if ($opt_d) {
	printf ("2. Inst: %4.1F $UNIT, Avg: %4.1f $UNIT, Var: %4.1f, low: %4.1f $UNIT, high: %4.1f $UNIT, CPU:% 3.1f\n",$sum2,$avg2,$var2,$low2,$hi2,$cpuu);    }

end: 	
    if (($sum > $MAXTHRPT) && (! $no-offload)) {
	map {print $_ . " "} @tmparray;
	print "\n";
    } elsif (($sum == 0) && ($zero_cnt > 10)) {
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
    $util/=(64);
    return $util;
}
