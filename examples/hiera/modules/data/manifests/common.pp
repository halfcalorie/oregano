# sets the common (across all oregano conf) ntp servers.
class data::common {
  $ntpservers = ['ntp1.example.com', 'ntp2.example.com']
}
