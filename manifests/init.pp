class marsnat {
  notice("Loading marsnat::init.pp")
  include marsnat::install
  include marsnat::service
}
