## 0.5.4 / 2014-08-30

* Improved ActiveModel support
* Fixed stale CAS on model reload

## 0.5.3 / 2013-06-06

* Prefer single-quoted strings (Andrey Koleshko)
* Test for Model.design_document (Andrey Koleshko)
* Support for batch finding multiple objects by id (Jon Moses)
* Test for activemodel instead of rails for activemodel validations
* Update couchbase dependency to 1.3.0

## 0.5.2 / 2013-02-25

* Fix attribute inheritance when subclassing (Mike Evans)
* Added as_json method for rails JSON responses (Stephen von Takach)
* Add contributing document
* Fix test hiding
* Remove comments from the javascript sources
* Reduce development dependencies and update jar version

## 0.5.1 / 2012-11-29

* Introduce save! and create! methods and raise RecordInvalid only from them

## 0.5.0 / 2012-11-21

* Update template for map function
* Use extended get for #find_by_id
* Do not use HashWithIndifferentAccess class unless it defined
* Pass options to #create method
* Ensure validness on create
* Fix storing raw data
* Define read_attribute and write_attribute methods
* Support couchbase 1.2.0.z.beta4

## 0.4.4 / 2012-10-17

* Make #to_param aware about keys

## 0.4.2 / 2012-10-17

* Update CAS value after mutation
* Added ability to pass options to mutators. Thanks to @kierangraham
* Always try to include Rails stuff into model
* Use key if id is nil (makes sense for some view results)

## 0.4.1 / 2012-09-26

* Put support notes in README
* Add note about validations in the README
* Update repo URL
* RCBC-85 Fix typo in `save' method

## 0.4.0 / 2012-09-25

* Add validation hooks for Rails application
* Check meta presence as more robust indicator of key presence

## 0.3.1 / 2012-09-22

* Allow to specify default storage options

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
