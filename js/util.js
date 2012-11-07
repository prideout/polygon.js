
  flatten = function(array) {
    var element, flattened, _i, _len;
    flattened = [];
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      element = array[_i];
      if (element instanceof Array) {
        flattened = flattened.concat(flatten(element));
      } else if (element instanceof vec2) {
        flattened = flattened.concat([element.x, element.y]);
      } else {
        flattened.push(element);
      }
    }
    return flattened;
  };
