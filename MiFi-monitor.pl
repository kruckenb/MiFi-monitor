#!/usr/bin/env perl

# Monitors MiFi. Use with GeekTool and/or Growl

use strict;
use warnings;
use Data::Dumper;

my $url = 'http://192.168.1.1/getStatus.cgi?dataType=TEXT';
my $status_file = '/tmp/lastMifiStatus.txt';
my %status;
for my $param (split('\x1B', `curl --connect-timeout 1 -s -S $url 2>&1`)) {
  my ($k, $v) = split('=', $param);
  if ($k && $v !~ /^\s*$/) {
    $k =~ s/^..//;
    $status{$k} = $v;
  }
}
my %last_status;
if (-e $status_file) {
  my $VAR1;
  eval(read_file($status_file));
  %last_status = %$VAR1;
}

my @growl_msg;
if (%status) {
  print $status{NetwkTech}, ' ', $status{ConnStatus} == 2 ? '*' x ($status{Rssi} || 0) : '-', "\n";

  push @growl_msg, "Disconnected"
    if $status{ConnStatus} != 2 && $last_status{ConnStatus} == 2;
  push @growl_msg, "1xRTT"
    if $status{NetwkTech} !~ /EVDO/i && $last_status{NetwkTech} =~ /EVDO/i;
  push @growl_msg, "EvDO"
    if $status{NetwkTech} =~ /EVDO/i && $last_status{NetwkTech} !~ /EVDO/i;

  if ($status{Roaming}) {
    print "Roaming\n";
    push @growl_msg, "Roaming" if !$last_status{Roaming};
  }

  if ($status{BattChg}) {
    print "Charging\n";
    push @growl_msg, "Charging" if !$last_status{BattChg};
  } elsif (!$status{BattChg} && $status{BattStat} < 4) {
    push @growl_msg, "Battery discharging" if $last_status{BattChg} || $last_status{BattStat} == 4;
    print "Draining\n";
  }

  if (@growl_msg && `which growlnotify`) {
    open my $g, "| growlnotify -s -m -";
    print $g "MiFi Status:\n\n", join("\n", @growl_msg);
    close $g;
  }

  open my $fh, "> $status_file";
  print $fh Dumper(\%status);
  close $fh;
}

sub read_file {
  return do { local $/; open my $fh, shift; <$fh>; }
}
