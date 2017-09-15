function oregano_init_calling_oregano() {
  usee::usee_oregano()
}

function oregano_init_calling_oregano_init() {
  usee_oregano_init()
}

function oregano_init_calling_ruby() {
  usee::usee_ruby()
}

class user {
  # Dummy resource. Added just to assert that a ruby type in another module is loaded correctly
  # by the auto loader
  Usee_type {
    name => 'pelle'
  }

  case $::case_number {
    1: {
      # Call a oregano function that resides in usee/functions directly from init.pp
      #
      notify { 'case_1': message => usee::usee_oregano() }
    }
    2: {
      # Call a oregano function that resides in usee/manifests/init.pp directly from init.pp
      #
      include usee
      notify { 'case_2': message => usee_oregano_init() }
    }
    3: {
      # Call a ruby function that resides in usee directly from init.pp
      #
      notify { 'case_3': message => usee::usee_ruby() }
    }
    4: {
      # Call a oregano function that resides in usee/functions from a oregano function under functions
      #
      notify { 'case_4': message => user::oregano_calling_oregano() }
    }
    5: {
      # Call a oregano function that resides in usee/manifests/init.pp from a oregano function under functions
      #
      include usee
      notify { 'case_5': message => user::oregano_calling_oregano_init() }
    }
    6: {
      # Call a ruby function that resides in usee from a oregano function under functions
      #
      notify { 'case_6': message => user::oregano_calling_ruby() }
    }
    7: {
      # Call a oregano function that resides in usee/functions from a oregano function in init.pp
      #
      notify { 'case_7': message => oregano_init_calling_oregano() }
    }
    8: {
      # Call a oregano function that resides in usee/manifests/init.pp from a oregano function in init.pp
      #
      include usee
      notify { 'case_8': message => oregano_init_calling_oregano_init() }
    }
    9: {
      # Call a ruby function that resides in usee from a oregano function in init.pp
      #
      notify { 'case_9': message => oregano_init_calling_ruby() }
    }
    10: {
      # Call a oregano function that resides in usee/functions from a ruby function in this module
      #
      notify { 'case_10': message => user::ruby_calling_oregano() }
    }
    11: {
      # Call a oregano function that resides in usee/manifests/init.pp from a ruby function in this module
      #
      include usee
      notify { 'case_11': message => user::ruby_calling_oregano_init() }
    }
    12: {
      # Call a ruby function that resides in usee from a ruby function in this module
      #
      notify { 'case_12': message => user::ruby_calling_ruby() }
    }
  }
}

