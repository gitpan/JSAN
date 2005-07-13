#line 1 "inc/CPANPLUS/Config.pm - /Library/Perl/5.8.6/CPANPLUS/Config.pm"
###############################################
###           CPANPLUS::Config              ###
###  Configuration structure for CPANPLUS   ###
###############################################

#last changed: Wed May  4 16:23:56 2005 GMT

### minimal pod, so you can find it with perldoc -l, etc
#line 21

package CPANPLUS::Config;

$VERSION = "0.050_04";

$MIN_CPANPLUS_VERSION = "0.050_03";

use strict;

sub new {
    my $class = shift;

    my $conf = {
                 '_fetch' => {
                               'blacklist' => [
                                                'ftp'
                                              ]
                             },
                 '_daemon' => {
                                'password' => '',
                                'port' => '1337',
                                'username' => 'cpanplus'
                              },
                 'conf' => {
                             'verbose' => 0,
                             'hosts' => [
                                          {
                                            'path' => '/Users/cwest/Documents/CPAN',
                                            'scheme' => 'file',
                                            'host' => ''
                                          },
                                          {
                                            'path' => '/',
                                            'scheme' => 'http',
                                            'host' => 'www.cpan.org'
                                          },
                                          {
                                            'path' => '/pub/CPAN/',
                                            'scheme' => 'ftp',
                                            'host' => 'ftp.nl.uu.net'
                                          },
                                          {
                                            'path' => '/pub/CPAN/',
                                            'scheme' => 'ftp',
                                            'host' => 'cpan.valueclick.com'
                                          },
                                          {
                                            'path' => '/pub/languages/perl/CPAN/',
                                            'scheme' => 'ftp',
                                            'host' => 'ftp.funet.fi'
                                          }
                                        ],
                             'storable' => 1,
                             'skiptest' => 0,
                             'makeflags' => '',
                             'fetchdir' => '',
                             'email' => 'cpanplus@example.com',
                             'dist_type' => '',
                             'timeout' => 300,
                             'prefer_makefile' => 0,
                             'makemakerflags' => '',
                             'debug' => 0,
                             'lib' => [],
                             'shell' => 'CPANPLUS::Shell::Default',
                             'prefer_bin' => 0,
                             'base' => '/Users/cwest/.cpanplus',
                             'extractdir' => '',
                             'no_update' => 0,
                             'buildflags' => '',
                             'force' => 0,
                             'cpantest' => 0,
                             'prereqs' => '2',
                             'flush' => 1,
                             'signature' => 0,
                             'allow_build_interactivity' => 1,
                             'passive' => 1,
                             'md5' => 1
                           },
                 'program' => {
                                'perl' => '',
                                'make' => '/usr/bin/make',
                                'editor' => '/usr/bin/emacs',
                                'pager' => '/usr/bin/less',
                                'shell' => '/bin/bash',
                                'sudo' => '/usr/bin/sudo'
                              },
                 '_source' => {
                                'auth' => '01mailrc.txt.gz',
                                'hosts' => 'MIRRORED.BY',
                                'stored' => 'sourcefiles',
                                'dslip' => '03modlist.data.gz',
                                'update' => '86400',
                                'mod' => '02packages.details.txt.gz'
                              },
                 '_build' => {
                               'moddir' => 'build/',
                               'distdir' => 'dist/',
                               'startdir' => '/Users/cwest/.cpan/build/CPANPLUS-0.053',
                               'plugins' => 'plugins/',
                               'sanity_check' => 1,
                               'autdir' => 'authors/',
                               'autobundle_prefix' => 'Snapshot',
                               'autobundle' => 'autobundle/'
                             },
                 '_mirror' => {
                                'auth' => 'authors/01mailrc.txt.gz',
                                'base' => 'authors/id/',
                                'dslip' => 'modules/03modlist.data.gz',
                                'mod' => 'modules/02packages.details.txt.gz'
                              },
                 '_dist' => {
                              'CPANPLUS::Dist::MM' => 1,
                              'CPANPLUS::Dist::Build' => 1
                            }
    };

    bless($conf, $class);
    return $conf;

} #new


1;

