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
    

# Recover the parameters: 
my $source = "/home/jbarbay/Unison/AudioNotesToProcess/";
my $destination = "/home/jbarbay/ToArchive/AudioNotesArchived/";
my $movingFiles=1; # True

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
print("Total number of audio notes to process: ");
system("ls -l ~/AudioNotesToProcess/*/*.WAV | wc -l");

# print "\n";
# moveVoiceFolder();  # I kept the code here, but now I use a separate script for this: [[file:~/bin/processDictaphone.pl]]

print "\n";
# First call to the recursive function:
process_dir("");



sub moveVoiceFolder {
# Automatically Move and rename of "Voice" folder on Dictaphone, and umount at the end

    my $dictaphonePlugged=0; # False
    my $dictaphoneMount="/media/DICTAPHONE";
    my $dictaphoneFolder="/media/DICTAPHONE/Record/Voice";
    
    if( -e $dictaphoneFolder ) {
	$dictaphonePlugged=1; # True
	print("Moving and renaming the file '/media/DICTAPHONE/Record/Voice':\n");
	
	# Recover statistics:
	my $stats = stat($dictaphoneFolder) or die "Error while recovering stats: $!!\n";
	my $cdate = localtime($stats->ctime);
	print "Creation Time\t: ",$cdate, "\n";
	my $mdate = localtime($stats->mtime);
	print "Modif Time\t: ", $mdate, "\n";
	my $adate = localtime($stats->atime);
	print "Access Time\t: ",$adate, "\n";
	my $backupDate = localtime();
	print "Back-up Time (today)\t: ", $backupDate, "\n";
	
	# Parse supposing $mdate follows the format "Sun Nov 28 06:25:26 2010" 
	my ($wday, $tmonth, $mday, $hour, $min, $sec, $year) = ($backupDate =~
								/(\w+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)/) or die("Problem parsing modification date: $!!\n");
	
	# translate textual month into digital value:
	my %mon2num = qw(jan 01 feb 02 mar 03 apr 04 may 05 jun 06 jul 07 aug 08 sep 09 oct 10 nov 11 dec 12); 
	my $month = $mon2num{ lc substr($tmonth, 0, 3) };

	# add a leading zero to the day if less than 10.
	my $smday = "";
	if( $mday < 10 ) {
	    $smday = "0".$mday;
	} else {
	    $smday = $mday;
	}

	# Build new name of Folder:
	my $baseNewFolderName = $year."-".$month."-".$smday."_".$hour."-".$min."-".$sec."";
	my $newFolderName = $baseNewFolderName;
	my $version = 0;
	while( -e $source.$newFolderName) {
	    $version = $version+1;
	    $newFolderName = $baseNewFolderName." version ".$version;
	}
	
	# Move the file to the TOPROCESS folder:
	print("mv '".$dictaphoneFolder."' '".$source.$newFolderName."'\n");
	system("mv '".$dictaphoneFolder."' '".$source.$newFolderName."'\n");
	
	# Umount the dictaphone
	print("umount '".$dictaphoneMount."'\n");
	system("umount '".$dictaphoneMount."'\n");
    }
}



# Action on each wave file
sub process_file { 
        my ($f) = shift;                 # file to process
	my ($relativePath) = shift;      # relative path
	my ($nbFilesProcessed) = shift;  # rank of the file in the folder
	my ($nbFiles) = shift;           # total number of wav files in the folder
	

	if( -e $source.$relativePath.$f ) {

	    # print("CHECKED: file '".$source.$relativePath.$f."' does exit.\n");	
	    do { 
		print("Playing file '".$source.$relativePath.$f."'.\n");
		
		# Recover and show statistics:
		my $stats = stat($source.$relativePath.$f) or die "Error while recovering stats: $!!\n";
		my $cdate = localtime($stats->ctime);
		print "Creation Time\t: ",$cdate, "\n";
		my $mdate = localtime($stats->mtime);
		print "\033[1mLast Modif Time\t: ", $mdate, " \033[0m\n";

		my $filesize = ($stats->size)/1024; # or die "Error while recovering size from stats: $!!\n";	    
		printf "File Size\t: %uK", $filesize;
		
                # Estimate of the number of audionotes left to read:
		print("\n\n\033[1mNumber of audio notes left: ");
		system("ls -l ~/AudioNotesToProcess/*/*.WAV | wc -l");
		print "\033[0m";

		# Play file:
		system("play  '".$source.$relativePath.$f."'\n");		

		# Take user input.
		print("Press "
		      ."'Enter' for repeat,"
		      ."'Ctrl-d' for next file, "
		      ."'Ctrl-c' for exit "
		      ."(".$nbFilesProcessed." processed, "
		      .($nbFiles-$nbFilesProcessed)." to go in this folder).\n");
	    } until ( !<STDIN> );	
	    if ( $movingFiles ) {
		print("Archiving ".$source.$relativePath.$f." to ".$destination.$relativePath."\n");
		system("mv '".$source.$relativePath.$f."' '".$destination.$relativePath."'\n");
	    }
	} else {
	    print("WARNING: file '".$source.$relativePath.$f."' does not seem to exit.\n");	    
	}
}
# Recursive Function which does most of the work:
sub process_dir {
    my ($relativePath) = shift;    # relative path

    # find all subdirectories and files
    print("Opening folder ".$source.$relativePath."\n");
    opendir(DIR, $source.$relativePath);
    my @entries = readdir(DIR);
    my @wavFiles = ();
    my @dirs = ();
    my ($e, $f, $d); # iterators for the three loops below
    my ($nbFiles,$nbFilesProcessed); # Counters
    
    # Sort the content of the folder between folders and WAV files:
    foreach $e (@entries) {
	if ( -d $source.$relativePath."/".$e && $e ne "." && $e ne ".."  && $e ne "CVS" && $e ne "auto" && $e ne "biblio" ) {
	    push @dirs, $e;
	}
	elsif ( -f $source.$relativePath."/".$e && ( $e =~ /\.WAV$/ ||  $e =~ /\.wav$/ ) ) {
	    push @wavFiles, $e;
	}	
    }
    $nbFiles=@wavFiles;
    print("Found ".$nbFiles." wav files in folder '".$source.$relativePath."'.\n\n");

    # Process WAV files:
    my @sfiles = sort { $a cmp $b } @wavFiles;
    $nbFilesProcessed=0;
    foreach $f (@sfiles) {
	$nbFilesProcessed++;
	process_file($f,$relativePath,$nbFilesProcessed,$nbFiles);
	print("\n");
    }

    # Recursively process folders:
    my @sdirs = reverse sort { $a cmp $b } @dirs;
    foreach $d (@sdirs) {
	print("Process recursively '".$d."'.\n");
	if ( $movingFiles ) {
	    print("mkdir -p ".$destination.$relativePath.$d."\n");
	    system("mkdir -p '".$destination.$relativePath.$d."'\n");
	}
	process_dir($relativePath.$d."/");
	if ( $movingFiles ) {
	    print("rmdir ".$source.$relativePath.$d."\n");
	    system("rmdir '".$source.$relativePath.$d."'\n");
	}
    }

}









