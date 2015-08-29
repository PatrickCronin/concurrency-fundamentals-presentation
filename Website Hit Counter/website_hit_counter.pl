#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(sys_wait_h);
use Readonly;

# Constants
Readonly my $HIT_COUNT_FILE => '/Users/pcronin/Projects by Client/Cronin Technology Consulting, LLC/Projects by Client/Ruby Brigade/Concurrency/Website Hit Counter/hit_count.txt';

# Set up the REAPER handler for dying children
$SIG{CHLD} = \&REAPER;

# Helper globals
my $NUM_CHILDREN = 1;
my $NUM_OPERATIONS = 10;
my $BUSY_CHILDREN = 0;

# Main program
read_program_args();
init_simulation();
run_simulation();
exit();

################################################################################
# SUBROUTINES ##################################################################
################################################################################

# Collect command line arguments
sub read_program_args {
    $NUM_CHILDREN = shift @ARGV;
    if (! defined $NUM_CHILDREN || $NUM_CHILDREN !~ m/^\d+$/) {
        usage();
    }
    
    $NUM_OPERATIONS = shift @ARGV;
    if (! defined $NUM_OPERATIONS || $NUM_OPERATIONS !~ m/^\d+$/) {
        usage();
    }
}

# Print program usage and quit
sub usage {
    print "usage: $0 <num_children> <num_operations>\n";
    exit;
}

# Set up simulation conditions
sub init_simulation {
    write_hit_count(0); # Create the hit count file if it doesn't exist
}

# Start simulation: produce and deploy children to do the work
sub run_simulation {
    foreach my $child_num (1 .. $NUM_CHILDREN) {
        $| = 1; # Autoflush STDOUT
        my $pid = fork();
        if (! defined $pid) {
            die "Not sure if I'm the parent or the child!";
        }
        elsif ($pid != 0) { # I am the parent
            print "Deployed child $child_num at PID $pid\n";
            $BUSY_CHILDREN++;
        }
        else { # I am the child
            child_work();
            exit();
        }
    }
    
    # Wait for any remaining children
    while ($BUSY_CHILDREN != 0) {
        sleep 1;
    }
}

# Child: do the work
sub child_work {
    sever_file_descriptors(); # Ensure a clean break from the parent
    
    foreach my $operation_num (1 .. $NUM_OPERATIONS) {
        increment_hit_count();
    }
}

# Close parent file descriptors and open new ones for the running child
sub sever_file_descriptors {
	close STDIN; open STDIN, '<' , '/dev/null';
	close STDOUT; open STDOUT, '>', '/dev/null';
	close STDERR; open STDERR, '>', '/dev/null';
}

# Increment the hit count in the hit count file by 1
sub increment_hit_count {
    my $current_hit_count = read_hit_count();
    $current_hit_count++;
    write_hit_count($current_hit_count);
}

# Read the hit count from the hit count file
sub read_hit_count {
    my $current_hit_count;

    # Read the hit count
    open HIT_COUNT, '<', $HIT_COUNT_FILE;
    $current_hit_count = <HIT_COUNT>;
    close HIT_COUNT;
    chomp $current_hit_count;
    
    # Reset hit count if unintelligible
    if ($current_hit_count !~ /^\d+$/) { 
        $current_hit_count = 0;
        write_hit_count($current_hit_count);
    }
    
    return $current_hit_count;
}

# Write the provided hit count to the hit count file
sub write_hit_count {
    my $new_hit_count = shift;
    
    open HIT_COUNT, '>', $HIT_COUNT_FILE;
    print HIT_COUNT $new_hit_count . "\n";
    close HIT_COUNT;
}

# Harvest children on their exit
sub REAPER {
	my $child;
	while (($child = waitpid(-1,WNOHANG)) > 0) {
        $BUSY_CHILDREN--;
		print "Reaped child $child [exit status $?]. Busy children: $BUSY_CHILDREN\n";
	}
	$SIG{CHLD} = \&REAPER;
}