#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;
use POSIX qw(SIGCHLD SIG_DFL);
use File::Basename;

my $port = $ENV{PORT} || 3000;
my $root = dirname(__FILE__);

my %mime = (
    html  => 'text/html; charset=utf-8',
    css   => 'text/css',
    js    => 'application/javascript',
    png   => 'image/png',
    jpg   => 'image/jpeg',
    jpeg  => 'image/jpeg',
    svg   => 'image/svg+xml',
    ico   => 'image/x-icon',
    woff2 => 'font/woff2',
);

my $server = IO::Socket::INET->new(
    LocalPort => $port,
    Type      => SOCK_STREAM,
    Reuse     => 1,
    Listen    => 10,
) or die "Cannot bind to port $port: $!";

print "Serving $root at http://localhost:$port/\n";
$| = 1;

while (my $client = $server->accept()) {
    my $request = '';
    while (my $line = <$client>) {
        $request .= $line;
        last if $line eq "\r\n";
    }

    my ($method, $path) = $request =~ /^(\w+)\s+(\S+)/;
    $path //= '/';
    $path = '/' if $path eq '';
    $path = '/index.html' if $path eq '/';
    $path =~ s/\?.*//;
    $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;

    my $file = $root . $path;
    $file =~ s|\\|/|g;

    if (-f $file) {
        my ($ext) = $file =~ /\.(\w+)$/;
        my $ct = $mime{lc($ext // '')} // 'application/octet-stream';
        open my $fh, '<:raw', $file or do {
            print $client "HTTP/1.1 500 Error\r\n\r\n";
            close $client; next;
        };
        local $/;
        my $body = <$fh>;
        close $fh;
        print $client "HTTP/1.1 200 OK\r\nContent-Type: $ct\r\nContent-Length: " . length($body) . "\r\nConnection: close\r\n\r\n$body";
    } else {
        my $body = "404 Not Found: $path";
        print $client "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: " . length($body) . "\r\n\r\n$body";
    }
    close $client;
}
