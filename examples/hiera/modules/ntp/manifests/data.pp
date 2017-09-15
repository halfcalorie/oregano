# this class will be loaded using hiera's 'oregano' backend
class ntp::data {
  $ntpservers = ['1.pool.ntp.org', '2.pool.ntp.org']
}
