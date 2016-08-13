package WWW::RiotGames::LeagueOfLegends;
use strict;
use warnings;
use Moo;
use LWP;
use JSON;
use URI;
use Sub::Name;
use Types::Standard qw(Str Int Enum InstanceOf);

our $VERSION = 0.0001;
$VERSION = eval $VERSION;

=head1 NAME

WWW::RiotGames::LeagueOfLegends - Perl wrapper around the Riot Games League of Legends API

=head1 SYNOPSIS

  use strict;
  use warnings;
  use aliased 'WWW::RiotGames::LeagueOfLegends' => 'LoL';

  my $lol = LoL->new(api_key => $api_key);
  # defaults ( region => 'na', timeout => 5 )

  my $champions = $lol->champion;
  my $champion_static_data = $lol->static_data(type => 'champion', id => 1, dataById => 0);
  my $summoner = $lol->summoner(by => 'name', id => 'summonername'));
  my $stats = $lol->stats(by => 'summoner', id => $summoner_id, type => 'ranked'));

=head1 DESCRIPTION

WWW::RiotGames::LeagueOfLegends is a simple Perl wrapper around the Riot Games League of Legends API.

It is as simple as creating a new WWW::RiotGames::LeagueOfLegends object and calling ->method
Each key/value pair becomes part of a query string, for example:

  $lol->static_data(type => 'champion', id => 1, dataById => 1);

results in the query string

  https://na.api.pvp.net/api/lol/static-data/na/v1.2/champion/1?dataById=1
  # api_key is added on

=head1 AUTHOR

Justin Hunter <justin.d.hunter@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Justin Hunter

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

my %api_methods = (
  champion => 1.2,
  #championmaster => undef,
  current_game => 1.0,
  #featured_games => 1.0,
  game => 1.3,
  league => 2.5,
  match => 2.2,
  matchlist => 2.2,
  static_data => 1.2,
  stats => 1.3,
  #status => 1.3,
  summoner => 1.4,
  team => 2.4,
);

has api_key => (
  is => 'ro',
  isa => Str,
  required => 1,
);

has region => (
  is => 'ro',
  isa => Enum[qw( br eune euw jp kr lan las na oce ru tr )],
  required => 1,
  default => sub { 'na' },
);

has ua => (
  is => 'lazy',
  handles => [ qw(request) ],
);

has api_url => (
  is => 'lazy',
  default => sub { 'https://' . $_[0]->region . '.api.pvp.net' },
);

has timeout => (
  is => 'rw',
  isa => Int,
  lazy => 1,
  default => sub { 5 },
);

has json => (
  isa => InstanceOf['JSON'],
  is => 'lazy',
  handles => [ qw(decode) ],
);

has debug => (
  is => 'rw',
  isa => Int,
  lazy => 1,
  default => sub { 0 },
);

my %region2platform = (
  na   => { id => 'NA1',  domain => 'spectator.na.lol.riotgames.com',   port => 80 },
  euw  => { id => 'EUW1', domain => 'spectator.euw1.lol.riotgames.com', port => 80 },
  eune => { id => 'EUN1', domain => 'spectator.eu.lol.riotgames.com',   port => 8088 },
  jp   => { id => 'JP1',  domain => 'spectator.jp1.lol.riotgames.com',  port => 80 },
  kr   => { id => 'KR',   domain => 'spectator.kr.lol.riotgames.com',   port => 80 },
  oce  => { id => 'OC1',  domain => 'spectator.oc1.lol.riotgames.com',  port => 80 },
  br   => { id => 'BR1',  domain => 'spectator.br.lol.riotgames.com',   port => 80 },
  lan  => { id => 'LA1',  domain => 'spectator.la1.lol.riotgames.com',  port => 80 },
  las  => { id => 'LA2',  domain => 'spectator.la2.lol.riotgames.com',  port => 80 },
  ru   => { id => 'RU',   domain => 'spectator.ru.lol.riotgames.com',   port => 80 },
  tr   => { id => 'TR1',  domain => 'spectator.tr.lol.riotgames.com',   port => 80 },
  pbe  => { id => 'PBE1', domain => 'spectator.pbe1.lol.riotgames.com', port => 8088 },
);

sub _build_ua {
  my $self = shift;
  my $ua = LWP::UserAgent->new( timeout => $self->timeout, agent => __PACKAGE__ . ' ' . $VERSION, ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0x00 } );
}

sub _build_json { JSON->new->utf8->allow_nonref }

sub _request {
  my $self = shift;
  my $method = shift;
  my %args = ref($_[0]) ? %{$_[0]} : @_;

  (my $api_method = $method) =~ s/_/-/g;

  my $api_url = $self->api_url;
  if ($method eq 'current_game') {
    $api_url .= '/observer-mode/rest/consumer/getSpectatorGameInfo/' . $region2platform{$self->region}{id};
  } else {
    $api_url .= '/api/lol/';
  }
  if ($method eq 'static_data') {
    $api_method = delete $args{type};
    $api_url .= 'static-data/';
  }

  $api_url .= $self->region . '/v' . $api_methods{$method} .'/' . $api_method unless $method eq 'current_game';
  $api_url .= '/by-' . delete $args{by} if exists $args{by};
  $api_url .= '/' . delete $args{id} if exists $args{id};
  $api_url .= '/' . delete $args{type} if exists $args{type};

  my $uri = URI->new($api_url);
  $uri->query_form(api_key => $self->api_key, %args);

  warn $uri->as_string if $self->debug;

  my $req = HTTP::Request->new('GET', $uri->as_string);
  my $response = $self->request( $req );
  return $response->is_success ? $self->decode($response->content) : $response->status_line;
}

no strict 'refs';
for my $method (keys %api_methods) {
  *{$method} = subname $method => sub { shift->_request($method, @_) };
}

1;
