#!/usr/bin/perl
# author Jan Stomphorst
# version 0.002 beta
# fixed space 

use strict;
use warnings;

my $debug = 1;  # if debug = 1 then debug else not
 # goal make backup of the machine selected in the options

# variable

#my $b_serv = 'prom-srv-robohelp';
#my $b_serv = 'pop-srv-vdfLSP';
#my $b_serv = 'outs-l-009';

#arguments
my ($b_serv,$backup_loc) = @ARGV;

if (not defined $b_serv){
  print "no server name found\nusage : backup-opserver.pl \"servername\"  \"backup location\"\n";
  exit;
} 

if (not defined $backup_loc){
  print "no location name found\nusage : backup-opserver.pl \"servername\"  \"backup location\"\n";
  exit;
} 

$backup_loc = "$backup_loc\/";
print "test : $backup_loc\n";

#looking if the location is working, else die!!
#my $backup_loc = "/mnt/ovirt_move/";
if (-d $backup_loc) {
  print "$backup_loc exists, go on..\n";
} else {
  print "$backup_loc location does not exist!\n";
  exit;
}

my $id = '';
my $run;
my @out;
my $out;

# locate machine id

$run = 'virsh -r list';
@out = `$run`;


foreach my $server (@out){
#  print $server;
  if ($server =~ /(\d+) .*$b_serv/) {
    print "$1 $b_serv \n"  if ($debug == 1);
    $id = $1;
  }
}

if ($id ne '') {
  # get all information dominfo domiflist domblklist 
  # qemu-img convert -p -O qcow2 source doel
  
#-dominfo-------------------------------------------------------------------------------------
  $run = "virsh -r dominfo $id";
  @out = `$run`; 

  my $type;
  my $maxmem;
  foreach my $line (@out){
    $type = $1 if ($line =~ /OS Type.* (.+)/);
    $maxmem = $1 if ($line =~ /Max memory.* (.+) KiB/);
  }
  print "$type\n"  if ($debug == 1);
  print "$maxmem\n"  if ($debug == 1);
#-domiflist-------------------------------------------------------------------------------------
  $run = "virsh -r domiflist $id";
  @out = `$run`; 

  my @mac;
  my @vlan;
  my @lan_type;
  foreach my $line (@out){
    if ($line =~ /(\w+) +(\w+) +(..:..:..:..:..:..)/){
      push (@vlan,$1);
      push (@lan_type,$2);
      push (@mac,$3);
    }
  }
  print "@vlan\n"  if ($debug == 1);
  print "@lan_type\n"  if ($debug == 1);
  print "@mac\n"  if ($debug == 1);
#-domblklist-------------------------------------------------------------------------------------
  $run = "virsh -r domblklist $id";
  @out = `$run`; 

  my @disk_type;
  my @disk;
  foreach my $line (@out){
    if ($line =~ /(\w+) +(\/.*)/){
      push (@disk_type,$1);
      push (@disk,$2);
    }
  }
  print "@disk_type\n"  if ($debug == 1); 
  print "@disk\n"  if ($debug == 1); 

#-size disk-------------------------------------------------------------------------------------
  my @size;
  my @bsize;
  my $tot = 0;
  foreach my $line (@disk){
    $run = "qemu-img info $line";
    $out = `$run`;  
#  virtual size: 325G (348966092800 bytes)   print "\n$out\n";
    if ($out =~ /size: (.*) \((.*) .*\)/){
      push (@size,$1);
      push (@bsize,$2);
      $tot = $tot + $2;
    }
  }  
  $tot = $tot / 1024;
  print "@size\n"  if ($debug == 1); 
  print "@bsize\n"  if ($debug == 1); 
  print "$tot\n"  if ($debug == 1); 

#-to file-------------------------------------------------------------------------------------

  $run = "df  -P --sync $backup_loc";
  @out = `$run`;
  my @avl = split(' ', $out[1]);
  my $avail = $avl[3];
  print "$avail kb\n"  if ($debug == 1);
  if ($tot > $avail) {
    print "Error not enough space $avail kb for $tot kb\n";
    exit;
  } else {
    print "checking the target space.... done\n";
  }



#-create backup-------------------------------------------------------------------------------------

  my @tot_time;
  my $count = 1;
  my @location;
  foreach my $l_disk (@disk){
    $run = "qemu-img convert -p -O qcow2 $l_disk $backup_loc$b_serv$count.qcow2";
    my $start_run = time();
    print "$run\n" if ($debug == 1);
    `$run`;
    if ($? == -1) {
      print "failed to execute: $!\n";
      exit;
    }
    my $end_run = time();
    my $run_time = $end_run - $start_run;
    print "$run_time\n" if ($debug == 1);
    push (@tot_time,$run_time);
    push (@location,"$backup_loc$b_serv$count.qcow2");
    ++$count;
  }





#-to file-------------------------------------------------------------------------------------


# cpu  and disk type

  #put all information in a file at backup loacation
  my $filename = "$backup_loc$b_serv.info";
  open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
  print $fh "information if the $b_serv virtual machine\n";
  print $fh "Type machine is :$type\n";
  print $fh "Memory : $maxmem\n";
  # need to sort the data
  print $fh "@mac\n";
  print $fh "@vlan\n";
  print $fh "@lan_type\n";
  print $fh "@disk_type\n"; 
  print $fh "@disk\n"; 
  print $fh "@size\n"; 
  print $fh "@bsize\n"; 
  print $fh "$tot\n"; 
  print $fh "backup time \n";
  print $fh "@tot_time\n";
  print $fh "@location";
  close $fh;

  print "find your information in file $backup_loc$b_serv.info\n";

#-done-------------------------------------------------------------------------------------
}else {
  print "Error Cannot find server $b_serv\n";
}

