class marsnat (
  $naticaversion        = hiera('naticaversion'),
  ) {
  notify{ "Loading marsnat::init.pp A": }
  notice("Loading marsnat::init.pp B")
  include marsnat::install
  include marsnat::service

}
