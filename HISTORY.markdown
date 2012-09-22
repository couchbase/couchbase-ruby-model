## 0.3.0 / 2012-09-22

* Implement belongs_to asscociation
* Use ActiveModel naming and conversion
* Define persisted? method
* Allow optional CAS value for mutators
* Use replace in save method. Thanks to @scalabl3
* Add callbacks for :save, :create, :update and :delete methods

## 0.2.0 / 2012-09-18

* Add Rails 3 configuration possibilities, allow configuring
  ensure_design_documents to disable/enable the auto view upgrade
  (thanks to David Rice)
* Ensure views directory is always set (thanks to David Rice)
* Fix tests for ruby 1.8.7
* Reword header in README
* Merge pull request #3 from davidjrice/master
* Use debugger gem
* Update Model wrapper to match latest API changes
* Strip contents of the JS file
* Do not submit empty views
* Allow to specify default view options
* Display only non-nil values
* Rename underscored methods
* Load spatial views into design document

## 0.1.0 / 2012-04-10

* Allows to define several attributes at once
* Allow to specify default value
* Add missing @since and @return tags
* Add railtie
* Add config generator
* Use verbose mode by default for GET operation
* Add views generators
* Update document wrapper
* Add code to upgrade design docs automatically
* Cache design document signature in memory
* Use symbols for attribute hash
* Skip connection errors during start up
* Don't show config warning for config generator
* Calculate mtime of the design document
* Assign current_doc after creation
* Update readme file
* Use preview repository for travis
* Do not make zipball
* Show model attributes with model class
* Update test. The couchbase gem is using new defaults

## 0.0.1/ 2012-03-17

* Initial version
