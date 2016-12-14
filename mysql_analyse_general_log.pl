#!/usr/bin/perl -w

# The mysql_analyse_general_log is Copyright (C) 2016 LINKBYNET,
#
# mysql_analyse_general_log.pl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# mysql_analyse_general_log.pl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ike-scan.  If not, see <http://www.gnu.org/licenses/>.
#
# mysql_analyse_general_log.pl -- Perl script to analyse MySQL general log
# and extract long running transactions or all non commited transactions at
# a specific time (crash time)
#
# Author: Julien Francoz <j.francoz@linkbynet.com>
# Date: December 2016

use strict;
use Getopt::Long;
use Time::Local;

my $current_time='000101 00:00:00'; # always init date in past
my $start_time='140101 00:00:00';
my $end_time  ='900101 23:59:59';
my $verbose=0;
my $debug=0;
my $display_partial_transaction=0;
my $min_duration=0;
my $only_at_end=0;
my $version="1.0";
my $display_version=0;
GetOptions (
	"version" => \$display_version,
	"start=s" => \$start_time,
	"end=s"   => \$end_time,
	"verbose" => \$verbose,
	"debug" => \$debug,
	"min-duration=i" => \$min_duration,
        "display-partial-transaction" => $display_partial_transaction,
	"only-at-end" => \$only_at_end,
) or usage();

sub usage {
	print STDERR "usage: cat general.log | $0 <--start='161205 15:03:19'> <--end='161205 16:10:05'> <--verbose> <--debug> <--min_duration=3> <--display-partial-transaction>\n";
	exit 1;
}

if ($display_version) {
	print "Version: $version\n";
	exit 0;
}

my $read_req_readahead='';

$start_time=normalize_time($start_time);
$end_time=normalize_time($end_time);

my $sessions;

# foreach request of logfile
while(my $log_request = read_req(\*STDIN)) {
        print "LOGLINE    : ".$log_request if $verbose;
        my ($date,$thread,$type,$query)=($log_request=~/^(.{16}|\s+)\s*([0-9]+)\s+(\w+)(\s+(.*))?/);

        $current_time = $date if ($date=~/^[0-9]/);
	$current_time=~s/\s+$//;

	# exclude request if not in time range
	print "DEBUG      : start_time=$start_time / current_time=".normalize_time($current_time)." / end_time: $end_time\n" if $debug;
	next if (normalize_time($current_time) < $start_time);
	next if (normalize_time($current_time) > $end_time);

        # manage autocommit for new sessions
        if (!exists($sessions->{$thread}->{'autocommit'})) {
                $sessions->{$thread}->{'autocommit'}=1; # defaut value of show session variables like '%autocommit%';
        }

	# manage begin of transaction (START TRANSACTION or SET AUTOCOMMIT=0)
        if ($query && $query=~/^\s*(START\s+TRANSACTION|SET\s+AUTOCOMMIT\s*=\s*0)/i) {
                $sessions->{$thread}->{'autocommit'}=0;
                $sessions->{$thread}->{'start'}=get_timestamp($current_time);
        }

	# manage disconnection
	if ($type =~ /Quit/i) {
		$query='ROLLBACK';
	}

	# save request in transaction or discard it if session is in autocommit
        my $log_line="$current_time : $type";
        $log_line.=" : $query" if ($query);
        if ($sessions->{$thread}->{'autocommit'}==1) {
        	# autocommit session, do not log
	} else {
		$sessions->{$thread}->{'queries'}.=";\n" if ($sessions->{$thread}->{'queries'});
        	$sessions->{$thread}->{'queries'}.="$log_line";
        	# TODO : count locks (insert,update ...)
		#$sessions->{$thread}->{'has_update'}++ if ($query && $query =~ /^\s*UPDATE/i);
	}

	# disconnect or COMMIT or ROLLBACK or SET AUTOCOMMIT=1
        if (($type =~/Quit/i)||($query && $query =~ /^\s*(commit|rollback|set autocommit\s*=\s*1)/i)) {
                # if commit or quit, display transaction
		if ($sessions->{$thread}->{autocommit}==0) {
                	$sessions->{$thread}->{'stop'}=get_timestamp($current_time);
                	$sessions->{$thread}->{'duration'}=$sessions->{$thread}->{'stop'}-$sessions->{$thread}->{'start'};
			if (($sessions->{$thread}->{'duration'} >= $min_duration) && !$only_at_end) {
				print "TRANS_END  : Transaction END : type: $type / query: $query / duration: $sessions->{$thread}->{'duration'}\n";
		                print_thread($thread);
			}
		} else {
			# nothing, connection was in autocommit mode
		}
                delete($sessions->{$thread});
        }

	# display statistics
	transaction_stat();
	transaction_list() if $display_partial_transaction;
}

# end of log
print "######## END ########\n";

# display informations about non finished transactions at this time
foreach my $thread (keys(%{$sessions})) {
        print_thread($thread);
        delete($sessions->{$thread});
}
# end of main


# print all requests of the transaction in a thread
sub print_thread {
        my $thread=shift;
	if ($sessions->{$thread}->{'queries'}) {
		my $duration=get_timestamp($current_time)-$sessions->{$thread}->{'start'};
		print "DEBUG_DURA : duration: $duration\n" if $debug;
		if ($duration >= $min_duration) {
	                print "THREAD_DMP : Thread $thread (partial duration:$duration):\n";
			my @Trans_Requests=split(/\n/,$sessions->{$thread}->{'queries'});
			foreach my $query (@Trans_Requests) {
				print "THREAD_DMP : $query\n";
			}
			print "\n";
		}
	}
}

# display statistics about current transactions
sub transaction_stat {
	my $no_autocommit_count=0;
	for my $thread (keys(%{$sessions})) {
		if (defined($sessions->{$thread}->{autocommit}) && $sessions->{$thread}->{autocommit} == 0) {
			$no_autocommit_count++;
			print "DEBUG      : $sessions->{$thread}->{queries}\n" if $debug;
		}
        }
	print "TRANS_STAT : == $current_time : stats ================================================\n" if $verbose;
	print "TRANS_STAT : $current_time: transactions non AUTOCOMMIT non commitées : $no_autocommit_count\n" if ($no_autocommit_count>0 && $verbose);
}

# display all active transactions
sub transaction_list {
	foreach my $thread (sort(keys(%{$sessions}))) {
		print_thread($thread);
	}
}

sub normalize_time {
  my $time=shift;
  $time=~s{
           (\d{2})(\d{2})(\d{2})\s+(\d+):(\d+):(\d+)
          }
          {
           sprintf '%02d%02d%02d%02d%02d%02d',
                    $1,  $2,  $3,  $4,  $5,  $6
          }xe
      or die "Failed to normalize '$time'\n";
  return $time;
}

sub get_timestamp {
  my $time=shift;
  $time=~s{
           (\d{2})(\d{2})(\d{2})\s+(\d+):(\d+):(\d+)
          }
          {
                    timelocal($6,$5,$4,$3,$2-1,'20'.$1);
          }xe
      or die "Failed to normalize '$time'\n";
  return $time;
}

# read lines of log until end of multiline request
sub read_req {
	my $fh=shift;
	while(1) {
		my $line=readline($fh);
                return 0 if (!defined($line));
		#print "line: $line\n";
		if (is_new_req($line)) {
			if ($read_req_readahead ne '') {
				my $out=$read_req_readahead;
				$read_req_readahead=$line;
				return $out;
			} else {
				$read_req_readahead = $line;
			}
		} else {
			$read_req_readahead.=$line;
		}
	}
}

# Is the line the beginning of a new request ?
sub is_new_req {
	my $line=shift;
	if ($line=~/^(.{16}|\s+)\s*([0-9]+)\s+(\w+)(\s+(.*))?/) {
		return 1;
	} else {
		return 0;
	}
}
