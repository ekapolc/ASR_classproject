#!/usr/bin/perl

use File::Basename;

if (@ARGV < 1) {
  exit -1;
}

$startdir = $ARGV[0];
$outdir = $ARGV[1];

$sox='/Users/ekapolc/Desktop/sox-14.4.2/sox';

opendir (DIR, $startdir) or die $!;
print "checking $startdir\n";
while ($file = readdir(DIR)) {
	$fullpath = $startdir."/".$file;
    @parts = split('\.',$file);
    if( @parts < 2) {next;}
    if( $parts[-1] eq 'wav') {
    	print "checking $file\n";
    	$ret = `$sox --i -t $fullpath`;
    	chomp($ret);
    	if ($ret ne "wav") {
    		print "WARNING $file not .wav\n";
    		next;
    	}
    	$ret = `$sox --i -c $fullpath`;
    	chomp($ret);
    	if ($ret ne "1") {
    		`$sox $fullpath /tmp/tmp.wav remix 1-2`;
    		$fullpath = '/tmp/tmp.wav';
    	}
    	$ret = `$sox --i -r $fullpath`;
    	chomp($ret);
    	if ($ret ne "16000") {
    		print "converting $file\n";
    		`$sox $fullpath -r 16000 -b 16 $outdir/$file`;
    		next;
    	}
    	$ret = `$sox --i -b $fullpath`;
    	chomp($ret);
    	if ($ret ne "16") {
    		print "converting $file\n";
    		`$sox $fullpath -r 16000 -b 16 $outdir/$file`;
    		next;
    	}
    	`cp $fullpath $outdir/$file`;
    }
}

closedir(DIR);