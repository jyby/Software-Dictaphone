#!/usr/bin/perl
use strict;
use warnings;
use File::stat;            # To get the time and size of a file
# use Time::localtime;       # localtime works WRONG when including this file???
# use "sox" linux package to get the application "play" to play wav files

# given no parameter, plays the wav files in the current folder.
#
# given a single parameter $source, plays using program "play" each
# "*.WAV" file found in the folder $source.
#
# given two parameters $source and $destination, additionally MOVE
# each file into the folder destination (which can be put to /dev/null
# to erase the files)

# Examples of Usage:

# * To read all wav files in the current folder without deleting nor moving them:
# > readWavFiles.pl

# * To read all wav files in the current folder and move them to the folder ARCHIVES (eventually creating it)
# > readWavFiles.pl ./ ARCHIVES/

# * To read all wav files on the DICTAPHONE and move them to ~/ARCHIVES/AUDIONOTES
# > readWavFiles.pl /media/DICTAPHONE/

# * To read all wav files and delete them:
# > touch trash
# > readWavFiles.pl ./ trash


print "# Perl Script to process audionotes from a jukebox SONY.\n";
print "# by Jeremy Barbay\n\n";
print "# Version last modified on [2019-03-19 Tue] \n\n";
    
    

# Recover the parameters: 
my $source = "/home/jbarbay/Unison/Boxes/MyBoxes/AudioNotesToProcess/";
my $destination = "/home/jbarbay/Unison/References/AudioNotesArchived/";
my $movingFiles=1; # True
my $debugLevel=0; # 0=silent, 1=print and run all system calls, 2=only print system calls.
my $logFile="/home/jbarbay/.audioNotes.log";
my $nbFiles;
my $nbFilesProcessed=0;

if ( @ARGV == 0 ) {
} elsif ( @ARGV == 1 ) {
    $source = shift;
} elsif ( @ARGV == 2 ) {
    $source = shift;
    $destination = shift;

    # Check if $destination exists (otherwise we might lose all files moving them to a single one)
    if ( -f $destination )  {
	print("WARNING! '".$destination."' is a file: all WAV files will be deleted (except the last one)!\n ");
    } elsif ( !(-d $destination) ) {
	print("Folder '".$destination."' does not exist, creating it.\n");
	system("mkdir '".$destination."'\n");
    }
}  else {
    die("Error with parameters (please read header in script)\n");
}


# Estimate of the number of audionotes left to read:
$nbFiles = trackNbAudioNotesLeftToRead("$source");
print "Total number of audio notes to process: $nbFiles \n";
# system("ls -l $source/*/*.WAV | wc -l");

# First call to the recursive function which does everything:
process_dir("");
# And that's all!
print "\nThat's all folks!\n";


##############################################################################

# Recursive Function which does most of the work
sub process_dir {
    my ($relativePath) = shift;    # relative path

    # find all subdirectories and files
    if( ($debugLevel == 2) || ($debugLevel == 1) ) {
	print("Opening folder ".$source.$relativePath."\n");
    }
    opendir(DIR, $source.$relativePath);
    my @entries = readdir(DIR);
    my @wavFiles = ();
    my @dirs = ();
    my ($e, $f, $d); # iterators for the three loops below
    my ($nbFilesInThisFolder,$nbFilesProcessedInThisFolder); # Counters
    
    # Sort the content of the folder between folders and WAV files:
    foreach $e (@entries) {
	if ( -d $source.$relativePath."/".$e && $e ne "." && $e ne ".."  && $e ne "CVS" && $e ne "auto" && $e ne "biblio" ) {
	    push @dirs, $e;
	}
	elsif ( -f $source.$relativePath."/".$e && ( $e =~ /\.WAV$/ ||  $e =~ /\.wav$/ ) ) {
	    push @wavFiles, $e;
	}	
    }
    $nbFilesInThisFolder=@wavFiles;
    if( ($debugLevel == 2) || ($debugLevel == 1) ) {
	print("Found ".$nbFilesInThisFolder." wav files in folder '".$source.$relativePath."'.\n\n");
    }

    # Process WAV files:
    my @sfiles = sort { $a cmp $b } @wavFiles;
    $nbFilesProcessedInThisFolder=0;
    foreach $f (@sfiles) {
	process_file($f,$relativePath,$nbFilesProcessedInThisFolder,$nbFilesInThisFolder);
	$nbFilesProcessedInThisFolder++;
	$nbFilesProcessed++;
	print "\n";
    }

    # Recursively process folders:
    my @sdirs = reverse sort { $a cmp $b } @dirs;
    foreach $d (@sdirs) {
	print("Process recursively '".$d."'.\n\n");
	if ( $movingFiles ) {
	    if( ($debugLevel == 2) || ($debugLevel == 1) ) {
		print("mkdir -p ".$destination.$relativePath.$d."\n");
	    }
	    if( ($debugLevel == 0) || ($debugLevel == 1) ) {
		system("mkdir -p '".$destination.$relativePath.$d."'\n");
	    }
	}
	process_dir($relativePath.$d."/"); # Recursively process the directory and the files it contains.
	if ( $movingFiles ) {
	    if( ($debugLevel == 2) || ($debugLevel == 1) ) {
		print("rmdir ".$source.$relativePath.$d."\n");
	    }
	    if( ($debugLevel == 0) || ($debugLevel == 1) ) {
		system("rmdir '".$source.$relativePath.$d."'\n");
	    }
	}
    }

}



# Action on each wave file
sub process_file { 
        my ($f) = shift;                 # file to process
	my ($relativePath) = shift;      # relative path
	my ($nbFilesProcessedInThisFolder) = shift;  # rank of the file in the folder
	my ($nbFilesInThisFolder) = shift;           # total number of wav files in the folder
	
	if( -e $source.$relativePath.$f ) {

	    do { 
		# Show how many audionotes processed in this folder.
		print("\033[1m"
		      ."Folder: [".($nbFilesProcessedInThisFolder+1)."/".$nbFilesInThisFolder."]; "
		      ."Session [".($nbFilesProcessed+1)."/".$nbFiles."];"
		      ."\033[0m\n");

		if( ($debugLevel == 2) || ($debugLevel == 1) ) {
		    print("Playing file '".$source.$relativePath.$f."'.\n");
		}
		
		# Recover and show statistics:
		my $stats = stat($source.$relativePath.$f) or die "Error while recovering stats: $!!\n";
		my $cdate = localtime($stats->ctime);
		my $mdate = localtime($stats->mtime);
		my $filesize = ($stats->size)/1024; # or die "Error while recovering size from stats: $!!\n";	    
		if( ($debugLevel == 2) || ($debugLevel == 1) ) {		
		    print "Creation Time\t: ",$cdate, "\n";
		    print "Last Modif Time\t: ", $mdate, "\n";
		    printf "File Size\t: %uK", $filesize, "\n";
		}

		# Play file:
		if( ($debugLevel == 0) ) {
		    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($stats->ctime); # Creation time.
		    print "Note ".$f." archived";
		    printf(" on %u-%02u-%02u",(1900+$year),($mon+1),$mday);
		    printf(" at %02u:%02u",$hour,$min);
		    printf " (of size: %uK)", $filesize;
		    print ".\n";
		    system("play -q '".$source.$relativePath.$f."'\n");		
		} elsif( ($debugLevel == 1) ) {
		    print "play '".$source.$relativePath.$f."'\n";		
		    system("play  '".$source.$relativePath.$f."'\n");		
		} elsif ($debugLevel == 2) {
		    print "play '".$source.$relativePath.$f."'\n";		
		}


		# Take user input.
		print("Press "
		      ."'Enter' for repeat,"
		      ."'Ctrl-d' for next file, "
		      ."'Ctrl-c' for exit.\n");

	    } until ( !<STDIN> );	
	    if ( $movingFiles ) {
		if( ($debugLevel == 2) || ($debugLevel == 1) ) {
		    print("Archiving ".$source.$relativePath.$f." to ".$destination.$relativePath."\n");
		}
		if( ($debugLevel == 0) || ($debugLevel == 1) ) {
		    system("mv '".$source.$relativePath.$f."' '".$destination.$relativePath."'\n");
		}
	    }
	} else {
	    print("WARNING: file '".$source.$relativePath.$f."' does not seem to exit.\n");	    
	}
}


###################################################################

sub trackNbAudioNotesLeftToRead{
    my $AudioNotes = shift; # repertory containing the audionotes.
    my $absoluteTime = time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $count=estimateNbAudioNotesLeftToRead($AudioNotes);

    if( ($debugLevel == 0) | ($debugLevel == 1) ) {
	if( !(-e "${logFile}") ) {
	    open (LOGFILE, ">${logFile}") or die ("Cannot open file ${logFile} !!!");
	    print LOGFILE "# Log produced by the scripts =readWaveFiles.pl= and =processAudioNotes.pl=\n";
	    print LOGFILE "# ";
	    print LOGFILE "absoluteTime\t";
	    print LOGFILE "count\t";
	    print LOGFILE "yyyy\t";
	    print LOGFILE "mm-dd\t";
	    print LOGFILE "hh:mm:ss\t";
	    print LOGFILE "\n";
	} else {
	    open (LOGFILE, ">>${logFile}") or die ("Cannot open file ${logFile} !!!");
	}
	print LOGFILE "$absoluteTime\t";
	print LOGFILE "$count\t";
	print LOGFILE sprintf("%u\t",(1900+$year));
	print LOGFILE sprintf("%02u-%02u\t",($mon+1),$mday);
	print LOGFILE sprintf("%02u:%02u:%02u\t",$hour,$min,$sec);
	print LOGFILE "readWavFiles.pl\t";
	print LOGFILE "\n";
	close (LOGFILE);
    }     
    if( ($debugLevel == 2) | ($debugLevel == 1) ) {
	print "open $logFile\n";
	print  "absoluteTime\t";
	print  "count\t";
	print  "yyyy\t";
	print  "mm-dd\t";
	print  "hh:mm:ss\t";
	print "\n";
	print  "$absoluteTime\t";
	print  "$count\t";
	printf("%u\t",(1900+$year));
	printf("%02u-%02u\t",($mon+1),$mday);
	printf("%02u:%02u:%02u\t",$hour,$min,$sec);
	print  "readWavFiles.pl\t";
	print "\n";
	print  'close (LOGFILE);\n';
    } 
    return $count;
}

sub estimateNbAudioNotesLeftToRead {
    my ($topdir) = shift; # repertory containing the audionotes.
    opendir (DIR, $topdir) ; 
    my @entries = readdir(DIR);
    my @dirs = ();
    my $totalCount = 0;
    my $e;

    foreach $e (@entries) {
	if ( -d "$topdir/$e" && $e ne "." && $e ne ".." ) {
	    $totalCount = $totalCount + estimateNbAudioNotesLeftToRead("$topdir/$e");
	}
	elsif ( -f "$topdir/$e"  && ( ($e =~ /\.wav$/) || ($e =~ /\.WAV$/) )  ) {
	    $totalCount++;
	}
    }
    return $totalCount;
}

