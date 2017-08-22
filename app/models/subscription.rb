class Subscription < ApplicationRecord

  enum type: { test: 'test', full: 'full', evaluation: 'evaluation', oem: 'oem', provisional: 'provisional' }
  enum status: { expired: 'EXPIRED', active: 'ACTIVE', notactivated: 'NOTACTIVATED' }

end
