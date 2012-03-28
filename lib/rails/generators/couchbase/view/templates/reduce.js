// If a view has a reduce function, it is used to produce aggregate results
// for that view. A reduce function is passed a set of intermediate values
// and combines them to a single value. Reduce functions must accept, as
// input, results emitted by its corresponding map function as well as
// results returned by the reduce function itself. The latter case is
// referred to as a rereduce.
//
//   function (key, values, rereduce) {
//     return sum(values);
//   }
//
// Reduce functions must handle two cases:
//
// 1. When rereduce is false:
//
//   reduce([ [key1,id1], [key2,id2], [key3,id3] ], [value1,value2,value3], false)
//
//   * key will be an array whose elements are arrays of the form [key,id],
//     where key is a key emitted by the map function and id is that of the
//     document from which the key was generated.
//   * values will be an array of the values emitted for the respective
//     elements in keys
//
// 2. When rereduce is true:
//
//   reduce(null, [intermediate1,intermediate2,intermediate3], true)
//
//   * key will be null
//   * values will be an array of values returned by previous calls to the
//     reduce function
//
// Reduce functions should return a single value, suitable for both the
// value field of the final view and as a member of the values array passed
// to the reduce function.
//
// NOTE: If this file is empty, reduce part will be skipped in design document
//
// There is number of built-in functions, which could be used instead of
// javascript implementation of reduce function.
//
// The _count function provides a simple count of the input rows from the
// map function, using the keys and group level to provide to provide a
// count of the correlated items. The values generated during the map()
// stage are ignored.
//
//   _count
//
// The built-in _sum function collates the output from the map function
// call. The information can either be a single number or an array of numbers.
//
//   _sum
//
// The _stats built-in produces statistical calculations for the input data.
// Like the _sum call the source information should be a number. The
// generated statistics include the sum, count, minimum (min), maximum (max)
// and sum squared (sumsqr) of the input rows.
//
//   _stats
//
// Read more about how to write reduce functions at:
// http://www.couchbase.com/docs/couchbase-manual-2.0/couchbase-views-writing-reduce.html
