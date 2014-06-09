var define, requireModule, require, requirejs;

(function() {
  var registry = {}, seen = {};

  define = function(name, deps, callback) {
    registry[name] = { deps: deps, callback: callback };
  };

  requirejs = require = requireModule = function(name) {
  requirejs._eak_seen = registry;

    if (seen.hasOwnProperty(name)) { return seen[name]; }
    seen[name] = {};

    if (!registry[name]) {
      throw new Error("Could not find module " + name);
    }

    var mod = registry[name],
        deps = mod.deps,
        callback = mod.callback,
        reified = [],
        exports;

    for (var i=0, l=deps.length; i<l; i++) {
      if (deps[i] === 'exports') {
        reified.push(exports = {});
      } else {
        reified.push(requireModule(resolve(deps[i])));
      }
    }

    var value = callback.apply(this, reified);
    return seen[name] = exports || value;

    function resolve(child) {
      if (child.charAt(0) !== '.') { return child; }
      var parts = child.split("/");
      var parentBase = name.split("/").slice(0, -1);

      for (var i=0, l=parts.length; i<l; i++) {
        var part = parts[i];

        if (part === '..') { parentBase.pop(); }
        else if (part === '.') { continue; }
        else { parentBase.push(part); }
      }

      return parentBase.join("/");
    }
  };
})();
define("canvas-image", 
  ["drawing","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    var drawing = __dependency1__["default"];
    var CanvasImage,
      __hasProp = {}.hasOwnProperty,
      __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

    CanvasImage = (function(_super) {
      __extends(CanvasImage, _super);

      function CanvasImage(options) {
        CanvasImage.__super__.constructor.call(this, options);
        this.source = options.source;
        this.naturalWidth = options.naturalWidth;
        this.naturalHeight = options.naturalHeight;
        this.originalNaturalBounds = this.naturalBounds();
        this.cropped = false;
        this.history = [];
        this.loaded = false;
        this.cropX = 0;
        this.cropY = 0;
        this.cropWidth = this.naturalWidth;
        this.cropHeight = this.naturalHeight;
        this.loadImage();
      }

      CanvasImage.prototype.clearImage = function() {
        this.loaded = false;
        this.cropped = false;
        this.w = null;
        this.h = null;
        this.naturalWidth = null;
        this.naturalHeight = null;
        this.history = [];
        this.originalNaturalBounds = this.naturalBounds();
        return this.markDirty();
      };

      CanvasImage.prototype.setSource = function(source) {
        this.clearImage();
        this.source = source;
        return this.loadImage();
      };

      CanvasImage.prototype.naturalBounds = function() {
        return {
          x: 0,
          y: 0,
          w: this.naturalWidth,
          h: this.naturalHeight
        };
      };

      CanvasImage.prototype.cropFrame = function() {
        return {
          x: this.cropX,
          y: this.cropY,
          w: this.cropWidth,
          h: this.cropHeight
        };
      };

      CanvasImage.prototype.crop = function(frame) {
        var previousCrop;
        if (!this.cropped) {
          this.cropped = true;
          this.cropX = this.cropY = 0;
        }
        previousCrop = this.cropFrame();
        this.cropX = frame.x + this.cropX;
        this.cropY = frame.y + this.cropY;
        this.cropWidth = frame.width;
        this.cropHeight = frame.height;
        this.naturalWidth = this.cropWidth;
        this.naturalHeight = this.cropHeight;
        this.resizeToParent();
        this.centerOnParent();
        this.history.push({
          action: 'crop',
          fromCropFrame: previousCrop,
          toCropFrame: this.cropFrame()
        });
        this.trigger('crop', this, previousCrop, this.cropFrame());
        return this.markDirty();
      };

      CanvasImage.prototype.undoCrop = function() {
        var cropHistory, newCropFrame;
        if (this.history.length > 0) {
          cropHistory = this.history.pop();
          newCropFrame = cropHistory.fromCropFrame;
          this.cropX = newCropFrame.x;
          this.cropY = newCropFrame.y;
          this.cropWidth = newCropFrame.w;
          this.cropHeight = newCropFrame.h;
          this.naturalWidth = newCropFrame.w;
          this.naturalHeight = newCropFrame.h;
          this.resizeToParent();
          this.centerOnParent();
          if (this.history.length === 0) {
            this.cropped = false;
          }
          this.trigger('crop', this, cropHistory.toCropFrame, this.cropFrame());
          return this.markDirty();
        }
      };

      CanvasImage.prototype.revertImage = function() {
        var cropHistory;
        this.cropped = false;
        if (this.history.length > 0) {
          cropHistory = this.history.pop();
          this.cropX = 0;
          this.cropY = 0;
          this.cropWidth = this.originalNaturalBounds.w;
          this.cropHeight = this.originalNaturalBounds.h;
          this.naturalWidth = this.originalNaturalBounds.w;
          this.naturalHeight = this.originalNaturalBounds.h;
          this.resizeToParent();
          this.centerOnParent();
          this.trigger('crop', this, cropHistory.toCropFrame, this.cropFrame());
          this.history = [];
          return this.markDirty();
        }
      };

      CanvasImage.prototype.resizeToParent = function() {
        var ch, cw, scaleX, scaleY;
        cw = this.parent.frame().w;
        ch = this.parent.frame().h;
        scaleX = 1;
        scaleY = 1;
        if (this.naturalWidth > cw) {
          scaleX = cw / this.naturalWidth;
        }
        if (this.naturalHeight > ch) {
          scaleY = ch / this.naturalHeight;
        }
        this.scale = Math.min(scaleX, scaleY);
        this.w = (this.naturalWidth * this.scale) | 0;
        this.h = (this.naturalHeight * this.scale) | 0;
        return this.trigger('resize', this.frame());
      };

      CanvasImage.prototype.centerOnParent = function() {
        this.x = ((this.parent.frame().w / 2) - (this.w / 2)) | 0;
        this.y = ((this.parent.frame().h / 2) - (this.h / 2)) | 0;
        return this.trigger('reposition', this.frame());
      };

      CanvasImage.prototype.toDataURL = function(format) {
        var canvas, ctx;
        if (format == null) {
          format = 'image/png';
        }
        canvas = document.createElement('canvas');
        canvas.width = this.cropWidth;
        canvas.height = this.cropHeight;
        ctx = canvas.getContext('2d');
        if (this.cropped) {
          ctx.drawImage(this.img, this.cropX, this.cropY, this.cropWidth, this.cropHeight, 0, 0, this.cropWidth, this.cropHeight);
        } else {
          ctx.drawImage(this.img, 0, 0, this.cropWidth, this.cropHeight);
        }
        return canvas.toDataURL(format);
      };

      CanvasImage.prototype.draw = function(ctx) {
        return this.positionContext(ctx, function(ctx) {
          if (this.cropped) {
            return ctx.drawImage(this.img, this.cropX, this.cropY, this.cropWidth, this.cropHeight, 0, 0, this.w, this.h);
          } else {
            return ctx.drawImage(this.img, 0, 0, this.w, this.h);
          }
        });
      };

      CanvasImage.prototype.loadImage = function() {
        this.img = document.createElement('img');
        this.img.onload = (function(_this) {
          return function() {
            _this.loaded = true;
            _this.naturalWidth = _this.img.naturalWidth;
            _this.naturalHeight = _this.img.naturalHeight;
            _this.cropped = false;
            _this.history = [];
            _this.cropX = 0;
            _this.cropY = 0;
            _this.cropWidth = _this.img.naturalWidth;
            _this.cropHeight = _this.img.naturalHeight;
            _this.originalNaturalBounds = _this.naturalBounds();
            _this.markDirty();
            return _this.trigger('load', _this);
          };
        })(this);
        return this.img.src = this.source;
      };

      return CanvasImage;

    })(drawing.Drawable);

    __exports__["default"] = CanvasImage;
  });define("drawing", 
  ["funderscore","events","exports"],
  function(__dependency1__, __dependency2__, __exports__) {
    "use strict";
    var _ = __dependency1__["default"];
    var Events = __dependency2__["default"];
    var Drawable, PaddedContainer, Rectangle, drawing,
      __hasProp = {}.hasOwnProperty,
      __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
      __slice = [].slice;

    drawing = {};

    Drawable = (function(_super) {
      __extends(Drawable, _super);

      function Drawable(options) {
        this.options = options;
        this.x = options.x;
        this.y = options.y;
        this.w = options.w;
        this.h = options.h;
        this.dirty = true;
        this.scale = options.scale;
        this.parent = options.parent;
        this.canvas = options.canvas;
        this.children = options.children || [];
        this.dragable = options.dragable || false;
        this.enabled = options.enabled !== void 0 ? !!options.enabled : true;
      }

      Drawable.prototype.set = function(options) {
        var key, value, _results;
        _results = [];
        for (key in options) {
          if (!__hasProp.call(options, key)) continue;
          value = options[key];
          _results.push(this[key] = value);
        }
        return _results;
      };

      Drawable.prototype.enable = function(enabled) {
        var previous;
        previous = this.enabled;
        this.enabled = !!enabled;
        this.markDirty();
        if (previous !== this.enabled) {
          if (this.enabled) {
            return this.trigger('enabled', this);
          } else {
            return this.trigger('disabled', this);
          }
        }
      };

      Drawable.prototype.markDirty = function() {
        this.dirty = true;
        if (this.parent) {
          return this.parent.markDirty();
        }
      };

      Drawable.prototype.bubble = function() {
        var args, event, eventName, parent, _results;
        eventName = arguments[0], event = arguments[1], args = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
        event.currentTarget = this;
        this.trigger.apply(this, arguments);
        parent = this.parent;
        _results = [];
        while (parent) {
          event = _.clone(event);
          event.currentTarget = parent;
          parent.trigger.apply(parent, [eventName, event].concat(args));
          _results.push(parent = parent.parent);
        }
        return _results;
      };

      Drawable.prototype.findChildAtPoint = function(point) {
        var child, grandChild, i;
        i = this.children.length - 1;
        while (i >= 0) {
          child = this.children[i];
          grandChild = child.findChildAtPoint(point);
          if (grandChild) {
            return grandChild;
          } else {
            if (child.containsCanvasPoint(point)) {
              return child;
            }
          }
          i--;
        }
      };

      Drawable.prototype.bounds = function() {
        return {
          x: 0,
          y: 0,
          w: this.w,
          h: this.h
        };
      };

      Drawable.prototype.frame = function() {
        return {
          x: this.x,
          y: this.y,
          w: this.w,
          h: this.h
        };
      };

      Drawable.prototype.convertToParent = function(point) {
        var frame;
        frame = this.frame();
        return {
          x: point.x + frame.x,
          y: point.y + frame.y
        };
      };

      Drawable.prototype.convertFromParent = function(point) {
        var frame;
        frame = this.frame();
        return {
          x: point.x - frame.x,
          y: point.y - frame.y
        };
      };

      Drawable.prototype.convertToCanvas = function(point) {
        var parent, x, y;
        parent = this;
        x = point.x;
        y = point.y;
        while (parent) {
          x += parent.frame().x;
          y += parent.frame().y;
          parent = parent.parent;
        }
        return {
          x: x,
          y: y
        };
      };

      Drawable.prototype.convertFromCanvas = function(point) {
        var parent, x, y;
        parent = this;
        x = point.x;
        y = point.y;
        while (parent) {
          x -= parent.frame().x;
          y -= parent.frame().y;
          parent = parent.parent;
        }
        return {
          x: x,
          y: y
        };
      };

      Drawable.prototype.positionContext = function(ctx, fn) {
        var pos;
        if (this.parent) {
          pos = this.convertToCanvas(this.parent.bounds());
          ctx.translate(pos.x, pos.y);
        }
        return fn.call(this, ctx);
      };

      Drawable.prototype.containsCanvasPoint = function(point) {
        var localPoint;
        localPoint = this.convertFromCanvas(point);
        return this.containsPoint(localPoint);
      };

      Drawable.prototype.containsPoint = function(point) {
        var frame, _ref, _ref1;
        frame = this.frame();
        return (0 <= (_ref = point.x) && _ref <= frame.w) && (0 <= (_ref1 = point.y) && _ref1 <= frame.h);
      };

      Drawable.prototype.addChild = function(child) {
        child.parent = this;
        this.children.push(child);
        return this.markDirty();
      };

      Drawable.prototype.removeChild = function(child) {
        var i;
        i = this.children.indexOf(child);
        if (i >= 0) {
          child.parent = null;
          this.children.splice(i, 1);
          return this.markDirty();
        }
      };

      Drawable.prototype.renderChildren = function(ctx) {
        var child, _i, _len, _ref, _results;
        _ref = this.children;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          child = _ref[_i];
          if (child.enabled) {
            _results.push(child.render(ctx));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      };

      Drawable.prototype.clear = function(ctx) {
        var frame;
        frame = this.frame();
        if (this.parent) {
          return positionContext(ctx, (function(_this) {
            return function(ctx) {
              return ctx.clearRect(frame.x, frame.y, frame.w, frame.h);
            };
          })(this));
        } else {
          return ctx.clearRect(frame.x, frame.y, frame.w, frame.h);
        }
      };

      Drawable.prototype.render = function(ctx) {
        ctx.save();
        this.draw(ctx);
        ctx.restore();
        this.renderChildren(ctx);
        return this.dirty = false;
      };

      Drawable.prototype.draw = function(ctx) {};

      return Drawable;

    })(Events);

    drawing.Drawable = Drawable;

    PaddedContainer = (function(_super) {
      __extends(PaddedContainer, _super);

      function PaddedContainer(options) {
        if (options == null) {
          options = {};
        }
        PaddedContainer.__super__.constructor.call(this, options);
        this.padding = options.padding || 10;
        this.fillParent = options.fillParent || true;
      }

      PaddedContainer.prototype.frame = function() {
        var parentFrame;
        if (this.fillParent) {
          parentFrame = this.parent.frame();
          return {
            x: this.padding,
            y: this.padding,
            w: parentFrame.w - 2 * this.padding,
            h: parentFrame.h - 2 * this.padding
          };
        } else {
          return {
            x: this.x + this.padding,
            y: this.y + this.padding,
            w: this.w - 2 * this.padding,
            h: this.h - 2 * this.padding
          };
        }
      };

      PaddedContainer.prototype.bounds = function() {
        var parentFrame;
        if (this.fillParent) {
          parentFrame = this.parent.frame();
          return {
            x: 0,
            y: 0,
            w: parentFrame.w - 2 * this.padding,
            h: parentFrame.h - 2 * this.padding
          };
        } else {
          return {
            x: 0,
            y: 0,
            w: this.w - 2 * this.padding,
            h: this.h - 2 * this.padding
          };
        }
      };

      return PaddedContainer;

    })(Drawable);

    drawing.PaddedContainer = PaddedContainer;

    Rectangle = (function(_super) {
      __extends(Rectangle, _super);

      function Rectangle(options) {
        Rectangle.__super__.constructor.call(this, options);
        this.fillStyle = options.fillStyle || 'rgba(0, 0, 0, 0)';
        this.strokeStyle = options.strokeStyle;
        this.lineWidth = options.lineWidth;
      }

      Rectangle.prototype.draw = function(ctx) {
        return this.positionContext(ctx, (function(_this) {
          return function(ctx) {
            if (_this.fillStyle) {
              ctx.fillStyle = _this.fillStyle;
            }
            if (_this.strokeStyle) {
              ctx.strokeStyle = _this.strokeStyle;
            }
            if (_this.lineWidth) {
              ctx.lineWidth = _this.lineWidth;
            }
            ctx.beginPath();
            ctx.rect(0, 0, _this.w, _this.h);
            ctx.closePath();
            if (_this.fillStyle) {
              ctx.fill();
            }
            if (_this.lineWidth && _this.strokeStyle) {
              return ctx.stroke();
            }
          };
        })(this));
      };

      return Rectangle;

    })(Drawable);

    drawing.Rectangle = Rectangle;

    __exports__["default"] = drawing;
  });define("funderscore", 
  ["exports"],
  function(__exports__) {
    "use strict";
    var type, _, _fn, _i, _len, _ref;

    _ = {};

    _.clone = function(obj) {
      return _.extend({}, obj);
    };

    _.extend = function(obj, source) {
      var prop;
      if (source) {
        for (prop in source) {
          obj[prop] = source[prop];
        }
      }
      return obj;
    };

    _ref = ['Arguments', 'Function', 'String', 'Number', 'Date', 'RegExp'];
    _fn = function(type) {
      return _["is" + type] = function(obj) {
        return Object.prototype.toString.call(obj) === ("[object " + type + "]");
      };
    };
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      type = _ref[_i];
      _fn(type);
    }

    __exports__["default"] = _;
  });define("events", 
  ["funderscore","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    var _ = __dependency1__["default"];
    var Event, Events;

    Events = (function() {
      function Events() {}

      Events.prototype.on = function(event, callback, context) {
        var _base;
        this.events || (this.events = {});
        (_base = this.events)[event] || (_base[event] = []);
        if (_.isFunction(callback)) {
          return this.events[event].push([callback, context]);
        }
      };

      Events.prototype.trigger = function(event) {
        var callback, callbackStruct, callbacks, context, tail, _i, _len, _results;
        tail = Array.prototype.slice.call(arguments, 1);
        callbacks = this.events && this.events[event] ? this.events[event] : [];
        _results = [];
        for (_i = 0, _len = callbacks.length; _i < _len; _i++) {
          callbackStruct = callbacks[_i];
          callback = callbackStruct[0];
          context = callbackStruct[1] || this;
          _results.push(callback.apply(context, tail));
        }
        return _results;
      };

      return Events;

    })();

    Event = (function() {
      function Event(options) {
        var k, v;
        for (k in options) {
          v = options[k];
          this[k] = v;
        }
      }

      return Event;

    })();

    __exports__["default"] = Events;

    __exports__.Event = Event;
  });define("crop-box", 
  ["funderscore","drawing","exports"],
  function(__dependency1__, __dependency2__, __exports__) {
    "use strict";
    var _ = __dependency1__["default"];
    var drawing = __dependency2__["default"];
    var CropBox,
      __hasProp = {}.hasOwnProperty,
      __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

    CropBox = (function(_super) {
      __extends(CropBox, _super);

      function CropBox(options) {
        CropBox.__super__.constructor.call(this, _.extend({
          dragable: true
        }, options));
        this.image = options.image;
        this.handleSize = options.handleSize || 10;
        this.screenStyle = options.screenStyle || 'rgba(0, 0, 0, .75)';
        this.topScreen = new drawing.Rectangle({
          fillStyle: this.screenStyle
        });
        this.leftScreen = new drawing.Rectangle({
          fillStyle: this.screenStyle
        });
        this.rightScreen = new drawing.Rectangle({
          fillStyle: this.screenStyle
        });
        this.bottomScreen = new drawing.Rectangle({
          fillStyle: this.screenStyle
        });
        this.cropX = options.cropX || 0;
        this.cropY = options.cropY || 0;
        this.cropWidth = options.cropWidth || this.handleSize * 4;
        this.cropHeight = options.cropHeight || this.handleSize * 4;
        this.marchingAnts = options.marchingAnts || true;
        this.dashOffset = 0;
        this.dragging = null;
        this.mouseDown = false;
        this.handles = {};
        this.image.on('load', (function(_this) {
          return function() {
            return _this.setCropFrameAndUpdateFrame(_this.cropFrame());
          };
        })(this));
        this.image.on('crop', (function(_this) {
          return function(image, previousCrop, crop) {
            _this.cropX = previousCrop.w >= crop.w ? 0 : previousCrop.x - crop.x;
            _this.cropY = previousCrop.h >= crop.h ? 0 : previousCrop.y - crop.y;
            _this.cropWidth = previousCrop.w >= crop.w ? crop.w : previousCrop.w;
            _this.cropHeight = previousCrop.h >= crop.h ? crop.h : previousCrop.h;
            return _this.setCropFrameAndUpdateFrame(_this.cropFrame());
          };
        })(this));
        this.on('mouseout', this.onMouseOut);
        this.on('mousemove', this.onMouseMove);
        this.on('mousedown', this.onMouseDown);
        this.on('mouseup', this.onMouseUp);
        this.on('dragstart', this.onDragStart);
        this.on('dragend', this.onDragEnd);
        this.on('dragmove', this.onDragMove);
        this.setLooseTheAnts();
      }

      CropBox.prototype.frame = function() {
        return {
          x: this.w < 0 ? this.x + this.w : this.x,
          y: this.h < 0 ? this.y + this.h : this.y,
          w: Math.abs(this.w),
          h: Math.abs(this.h)
        };
      };

      CropBox.prototype.cropFrame = function() {
        return {
          x: this.cropX,
          y: this.cropY,
          width: this.cropWidth,
          height: this.cropHeight
        };
      };

      CropBox.prototype.updateCropFrameFromFrame = function() {
        var frame, imageBounds, naturalBounds;
        frame = this.frame();
        naturalBounds = this.image.naturalBounds();
        imageBounds = this.image.bounds();
        if (this.image.loaded) {
          this.cropX = naturalBounds.w * (frame.x / imageBounds.w);
          this.cropY = naturalBounds.h * (frame.y / imageBounds.h);
          this.cropWidth = naturalBounds.w * (frame.w / imageBounds.w);
          this.cropHeight = naturalBounds.h * (frame.h / imageBounds.h);
        }
        return this.trigger('change:cropFrame', this.cropFrame());
      };

      CropBox.prototype.setFrameAndUpdateCropArea = function(frame) {
        this.x = frame.x;
        this.y = frame.y;
        this.w = frame.w;
        this.h = frame.h;
        this.updateCropFrameFromFrame();
        return this.markDirty();
      };

      CropBox.prototype.updateFrameFromCropFrame = function() {
        var imageBounds, naturalBounds;
        if (this.image.loaded) {
          naturalBounds = this.image.naturalBounds();
          imageBounds = this.image.bounds();
          this.x = imageBounds.w * (this.cropX / naturalBounds.w);
          this.y = imageBounds.h * (this.cropY / naturalBounds.h);
          this.w = imageBounds.w * (this.cropWidth / naturalBounds.w);
          this.h = imageBounds.h * (this.cropHeight / naturalBounds.h);
          return this.markDirty();
        }
      };

      CropBox.prototype.setCropFrameAndUpdateFrame = function(cropArea) {
        var naturalBounds, newCropHeight, newCropWidth, newCropX, newCropY;
        if (this.image.loaded) {
          naturalBounds = this.image.naturalBounds();
          newCropX = (cropArea != null ? cropArea.x : void 0) || naturalBounds.w * .125;
          newCropY = (cropArea != null ? cropArea.y : void 0) || naturalBounds.h * .125;
          newCropWidth = (cropArea != null ? cropArea.width : void 0) || naturalBounds.w * .75;
          newCropHeight = (cropArea != null ? cropArea.height : void 0) || naturalBounds.h * .75;
          this.cropX = Math.min(Math.max(newCropX, 0), naturalBounds.w);
          this.cropY = Math.min(Math.max(newCropY, 0), naturalBounds.h);
          this.cropWidth = Math.min(Math.max(newCropWidth, 0), naturalBounds.w - this.cropX);
          this.cropHeight = Math.min(Math.max(newCropHeight, 0), naturalBounds.h - this.cropY);
          return this.updateFrameFromCropFrame();
        } else {
          this.cropX = cropArea != null ? cropArea.x : void 0;
          this.cropY = cropArea != null ? cropArea.y : void 0;
          this.cropWidth = cropArea != null ? cropArea.width : void 0;
          return this.cropHeight = cropArea != null ? cropArea.height : void 0;
        }
      };

      CropBox.prototype.bounds = function() {
        return {
          x: 0,
          y: 0,
          w: Math.abs(this.w),
          h: Math.abs(this.h)
        };
      };

      CropBox.prototype.containsCanvasPoint = function(point) {
        var containsPoint, direction, handle, local, _ref;
        local = this.convertFromCanvas(point);
        containsPoint = this.containsPoint(local);
        if (containsPoint) {
          return containsPoint;
        }
        _ref = this.handles;
        for (direction in _ref) {
          handle = _ref[direction];
          if (handle.containsCanvasPoint(point)) {
            return true;
          }
        }
        return false;
      };

      CropBox.prototype.onMouseOut = function(e) {
        return this.canvas.style.cursor = 'default';
      };

      CropBox.prototype.onMouseMove = function(e) {
        var direction, handle, point, _ref;
        if (!this.enabled) {
          return;
        }
        point = e.canvasPoint;
        _ref = this.handles;
        for (direction in _ref) {
          handle = _ref[direction];
          if (handle.containsCanvasPoint(point)) {
            switch (direction) {
              case 'tl':
                this.canvas.style.cursor = 'nw-resize';
                break;
              case 'tm':
                this.canvas.style.cursor = 'n-resize';
                break;
              case 'tr':
                this.canvas.style.cursor = 'ne-resize';
                break;
              case 'ml':
                this.canvas.style.cursor = 'w-resize';
                break;
              case 'mr':
                this.canvas.style.cursor = 'e-resize';
                break;
              case 'bl':
                this.canvas.style.cursor = 'sw-resize';
                break;
              case 'bm':
                this.canvas.style.cursor = 's-resize';
                break;
              case 'br':
                this.canvas.style.cursor = 'se-resize';
            }
            return;
          }
        }
        return this.canvas.style.cursor = 'move';
      };

      CropBox.prototype.constrainPointInParent = function(point) {
        return {
          x: Math.min(Math.max(point.x, 0), this.parent.frame().w),
          y: Math.min(Math.max(point.y, 0), this.parent.frame().h)
        };
      };

      CropBox.prototype.onMouseUp = function(point) {
        return this.dragging = this.mouseDown = null;
      };

      CropBox.prototype.onDragStart = function(e) {
        var direction, handle, localPoint, point, _ref;
        point = e.canvasPoint;
        _ref = this.handles;
        for (direction in _ref) {
          handle = _ref[direction];
          if (handle.containsCanvasPoint(point)) {
            localPoint = handle.convertFromCanvas(point);
            this.dragging = {
              resizeDirection: direction,
              object: handle,
              offsetX: localPoint.x,
              offsetY: localPoint.y
            };
            return;
          }
        }
        localPoint = this.convertFromCanvas(point);
        return this.dragging = {
          object: this,
          offsetX: localPoint.x,
          offsetY: localPoint.y
        };
      };

      CropBox.prototype.onDragMove = function(e) {
        var localPoint, parentPoint, point, _ref, _ref1;
        point = e.canvasPoint;
        if (((_ref = this.dragging) != null ? _ref.object : void 0) === this) {
          localPoint = this.convertFromCanvas(point);
          this.moveTo({
            x: localPoint.x - this.dragging.offsetX,
            y: localPoint.y - this.dragging.offsetY
          });
          this.updateCropFrameFromFrame();
          return this.markDirty();
        } else if ((_ref1 = this.dragging) != null ? _ref1.resizeDirection : void 0) {
          parentPoint = this.parent.convertFromCanvas(point);
          switch (this.dragging.resizeDirection) {
            case 'tl':
              point = this.constrainPointInParent(parentPoint);
              this.w = this.w + (this.x - point.x);
              this.h = this.h + (this.y - point.y);
              this.x = point.x;
              this.y = point.y;
              break;
            case 'tm':
              point = this.constrainPointInParent(parentPoint);
              this.w = this.w;
              this.h = this.h + (this.y - point.y);
              this.x = this.x;
              this.y = point.y;
              break;
            case 'tr':
              point = this.constrainPointInParent(parentPoint);
              this.w = point.x - this.x;
              this.h = this.h + (this.y - point.y);
              this.x = this.x;
              this.y = point.y;
              break;
            case 'ml':
              point = this.constrainPointInParent(parentPoint);
              this.w = this.w + (this.x - point.x);
              this.h = this.h;
              this.x = point.x;
              this.y = this.y;
              break;
            case 'mr':
              point = this.constrainPointInParent(parentPoint);
              this.w = point.x - this.x;
              this.h = this.h;
              this.x = this.x;
              this.y = this.y;
              break;
            case 'bl':
              point = this.constrainPointInParent(parentPoint);
              this.w = this.w + (this.x - point.x);
              this.h = point.y - this.y;
              this.x = point.x;
              this.y = this.y;
              break;
            case 'bm':
              point = this.constrainPointInParent(parentPoint);
              this.w = this.w;
              this.h = point.y - this.y;
              this.x = this.x;
              this.y = this.y;
              break;
            case 'br':
              point = this.constrainPointInParent(parentPoint);
              this.w = point.x - this.x;
              this.h = point.y - this.y;
              this.x = this.x;
              this.y = this.y;
          }
          this.updateCropFrameFromFrame();
          return this.markDirty();
        }
      };

      CropBox.prototype.onDragEnd = function(e) {
        var frame, point;
        point = e.canvasPoint;
        frame = this.frame();
        this.x = frame.x;
        this.y = frame.y;
        this.w = frame.w;
        this.h = frame.h;
        return this.trigger('change', this.cropFrame());
      };

      CropBox.prototype.onClick = function(e) {};

      CropBox.prototype.moveTo = function(point) {
        var pos, x, y;
        pos = this.convertToParent(point);
        x = Math.max(0, pos.x);
        y = Math.max(0, pos.y);
        x = Math.min(this.parent.bounds().w - this.w, x);
        y = Math.min(this.parent.bounds().h - this.h, y);
        this.x = x;
        return this.y = y;
      };

      CropBox.prototype.setLooseTheAnts = function() {
        var animationFn;
        animationFn = (function(_this) {
          return function() {
            if (_this.marchingAnts) {
              _this.dashOffset += 0.15;
              _this.markDirty();
            }
            return window.requestAnimationFrame(animationFn);
          };
        })(this);
        return window.requestAnimationFrame(animationFn);
      };

      CropBox.prototype.drawScreen = function(ctx) {
        var frame;
        frame = this.frame();
        frame.x = Math.round(frame.x);
        frame.y = Math.round(frame.y);
        frame.w = Math.round(frame.w);
        frame.h = Math.round(frame.h);
        this.topScreen.set({
          parent: this.parent,
          x: 0,
          y: 0,
          w: this.parent.w,
          h: frame.y
        });
        this.bottomScreen.set({
          parent: this.parent,
          x: 0,
          y: frame.y + frame.h,
          w: this.parent.w,
          h: this.parent.h - (frame.y + frame.h)
        });
        this.leftScreen.set({
          parent: this.parent,
          x: 0,
          y: frame.y,
          w: frame.x,
          h: frame.h
        });
        this.rightScreen.set({
          parent: this.parent,
          x: frame.x + frame.w,
          y: frame.y,
          w: this.parent.w - (frame.x + frame.w),
          h: frame.h
        });
        this.topScreen.render(ctx);
        this.leftScreen.render(ctx);
        this.rightScreen.render(ctx);
        return this.bottomScreen.render(ctx);
      };

      CropBox.prototype.drawHandles = function(ctx) {
        var direction, frame, handle, newRect, _ref, _results;
        frame = this.frame();
        frame.x = Math.round(frame.x);
        frame.y = Math.round(frame.y);
        frame.w = Math.round(frame.w);
        frame.h = Math.round(frame.h);
        newRect = (function(_this) {
          return function(x, y) {
            return new drawing.Rectangle({
              parent: _this,
              x: x - (_this.handleSize / 2) - 0.5,
              y: y - (_this.handleSize / 2) - 0.5,
              w: _this.handleSize,
              h: _this.handleSize,
              lineWidth: 1,
              strokeStyle: 'rgba(192, 192, 192, 1)',
              fillStyle: 'rgba(64, 64, 64, 1)'
            });
          };
        })(this);
        this.handles["tl"] = newRect(0, 0);
        this.handles["tm"] = newRect(frame.w / 2, 0);
        this.handles["tr"] = newRect(frame.w, 0);
        this.handles["ml"] = newRect(0, frame.h / 2);
        this.handles["mr"] = newRect(frame.w, frame.h / 2);
        this.handles["bl"] = newRect(0, frame.h);
        this.handles["bm"] = newRect(frame.w / 2, frame.h);
        this.handles["br"] = newRect(frame.w, frame.h);
        _ref = this.handles;
        _results = [];
        for (direction in _ref) {
          handle = _ref[direction];
          _results.push(handle.render(ctx));
        }
        return _results;
      };

      CropBox.prototype.drawCropLines = function(ctx) {
        var frame, lineDash, opacity;
        frame = this.frame();
        frame.x = Math.round(frame.x);
        frame.y = Math.round(frame.y);
        frame.w = Math.round(frame.w);
        frame.h = Math.round(frame.h);
        opacity = "0.5";
        lineDash = 4;
        ctx.save();
        this.positionContext(ctx, (function(_this) {
          return function(ctx) {
            var x, y, _i, _j, _len, _len1, _ref, _ref1, _results;
            ctx.lineDashOffset = _this.dashOffset;
            ctx.beginPath();
            ctx.strokeStyle = "rgba(255,255,255," + (1 || opacity) + ")";
            ctx.rect(0.5, 0.5, frame.w, frame.h);
            ctx.closePath();
            ctx.stroke();
            ctx.beginPath();
            ctx.strokeStyle = "rgba(0,0,0," + (1 || opacity) + ")";
            ctx.setLineDash([lineDash]);
            ctx.rect(0.5, 0.5, frame.w, frame.h);
            ctx.closePath();
            ctx.stroke();
            ctx.lineDashOffset = 0;
            _ref = [frame.w / 3 + 0.5, (frame.w / 3) * 2 + 0.5];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              x = _ref[_i];
              ctx.beginPath();
              ctx.moveTo(x, 0);
              ctx.strokeStyle = "rgba(255,255,255," + opacity + ")";
              ctx.setLineDash([]);
              ctx.lineTo(x, frame.h);
              ctx.stroke();
              ctx.beginPath();
              ctx.moveTo(x, 0);
              ctx.strokeStyle = "rgba(0,0,0," + opacity + ")";
              ctx.setLineDash([lineDash]);
              ctx.lineTo(x, frame.h);
              ctx.stroke();
            }
            _ref1 = [frame.h / 3 + 0.5, (frame.h / 3) * 2 + 0.5];
            _results = [];
            for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
              y = _ref1[_j];
              ctx.beginPath();
              ctx.moveTo(0, y);
              ctx.strokeStyle = "rgba(255,255,255," + opacity + ")";
              ctx.setLineDash([]);
              ctx.lineTo(frame.w, y);
              ctx.stroke();
              ctx.beginPath();
              ctx.moveTo(0, y);
              ctx.strokeStyle = "rgba(0,0,0," + opacity + ")";
              ctx.setLineDash([lineDash]);
              ctx.lineTo(frame.w, y);
              _results.push(ctx.stroke());
            }
            return _results;
          };
        })(this));
        return ctx.restore();
      };

      CropBox.prototype.draw = function(ctx) {
        this.drawScreen(ctx);
        this.drawCropLines(ctx);
        return this.drawHandles(ctx);
      };

      return CropBox;

    })(drawing.Drawable);

    __exports__["default"] = CropBox;
  });define("rodeo-crop", 
  ["funderscore","drawing","events","canvas-image","crop-box","stage","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __dependency4__, __dependency5__, __dependency6__, __exports__) {
    "use strict";
    var _ = __dependency1__["default"];
    var drawing = __dependency2__["default"];
    var Events = __dependency3__["default"];
    var CanvasImage = __dependency4__["default"];
    var CropBox = __dependency5__["default"];
    var Stage = __dependency6__["default"];
    var Cropper, RodeoCrop,
      __hasProp = {}.hasOwnProperty,
      __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

    RodeoCrop = {};

    Cropper = (function(_super) {
      __extends(Cropper, _super);

      function Cropper(el, options) {
        this.el = _.isString(el) ? document.querySelector(el) : el;
        this.options = _.extend({
          cropEnabled: true,
          cropX: null,
          cropY: null,
          cropWidth: null,
          cropHeight: null,
          marchingAnts: true,
          handleSize: 10,
          width: 100,
          height: 100,
          imageSource: null
        }, options);
        this.ctx = null;
        this.stage = null;
        this.imageSource = this.options.imageSource;
        this.initializeCanvas();
        this.createStage();
        this.createImage();
        this.createCropBox();
        this.runLoop();
      }

      Cropper.prototype.initializeCanvas = function() {
        this.canvas = document.createElement('canvas');
        this.canvas.width = this.options.width;
        this.canvas.height = this.options.height;
        this.canvas.style.display = 'block';
        this.el.appendChild(this.canvas);
        return this.ctx = this.canvas.getContext('2d');
      };

      Cropper.prototype.createStage = function() {
        return this.stage = new Stage({
          canvas: this.canvas
        });
      };

      Cropper.prototype.createImage = function() {
        this.paddedContainer = new drawing.PaddedContainer({
          padding: (this.options.handleSize / 2) + 1
        });
        this.image = new CanvasImage({
          canvas: this.canvas,
          source: this.imageSource
        });
        this.image.on('load', (function(_this) {
          return function() {
            _this.image.resizeToParent();
            return _this.image.centerOnParent();
          };
        })(this));
        this.stage.on('resize', (function(_this) {
          return function() {
            _this.image.resizeToParent();
            return _this.image.centerOnParent();
          };
        })(this));
        this.paddedContainer.addChild(this.image);
        return this.stage.addChild(this.paddedContainer);
      };

      Cropper.prototype.createCropBox = function() {
        this.cropBox = new CropBox({
          enabled: this.options.cropEnabled,
          canvas: this.canvas,
          image: this.image,
          cropX: this.options.cropX,
          cropY: this.options.cropY,
          cropWidth: this.options.cropWidth,
          cropHeight: this.options.cropHeight,
          handleSize: this.options.handleSize,
          marchingAnts: this.options.marchingAnts
        });
        this.cropBox.on('disabled', (function(_this) {
          return function(cropBox) {
            return _this.trigger('disabled', cropBox);
          };
        })(this));
        this.cropBox.on('enabled', (function(_this) {
          return function(cropBox) {
            return _this.trigger('enabled', cropBox);
          };
        })(this));
        this.cropBox.on('change', (function(_this) {
          return function(cropFrame) {
            return _this.trigger('change', cropFrame);
          };
        })(this));
        this.image.on('resize', (function(_this) {
          return function() {
            return _this.cropBox.updateFrameFromCropFrame();
          };
        })(this));
        return this.image.addChild(this.cropBox);
      };

      Cropper.prototype.isCropped = function() {
        return this.image.cropped;
      };

      Cropper.prototype.setImageSource = function(source) {
        return this.image.setSource(source);
      };

      Cropper.prototype.setCropFrame = function(frame) {
        this.cropBox.setCropFrameAndUpdateFrame(frame);
        return this.cropBox.cropFrame();
      };

      Cropper.prototype.enableCrop = function(enabled) {
        return this.cropBox.enable(enabled);
      };

      Cropper.prototype.revertImage = function() {
        return this.image.revertImage();
      };

      Cropper.prototype.undoCropImage = function() {
        return this.image.undoCrop();
      };

      Cropper.prototype.cropImage = function() {
        if (this.cropBox.enabled) {
          return this.image.crop(this.cropBox.cropFrame());
        }
      };

      Cropper.prototype.toDataURL = function(format) {
        if (format == null) {
          format = 'image/png';
        }
        return this.image.toDataURL(format);
      };

      Cropper.prototype.updateCanvasSize = function() {
        var h, w;
        w = window.getComputedStyle(this.canvas.parentNode).getPropertyValue('width');
        h = window.getComputedStyle(this.canvas.parentNode).getPropertyValue('height');
        w = parseInt(w, 10);
        h = parseInt(h, 10);
        if (this.canvas.width !== w || this.canvas.height !== h) {
          this.canvas.width = w;
          this.canvas.height = h;
          return true;
        } else {
          return false;
        }
      };

      Cropper.prototype.runLoop = function(arg) {
        var canvasSizeChanged;
        canvasSizeChanged = this.updateCanvasSize();
        if (canvasSizeChanged || this.stage.dirty) {
          this.stage.clear(this.ctx);
          if (canvasSizeChanged) {
            this.stage.trigger('resize');
          }
          this.stage.render(this.ctx);
        }
        return window.requestAnimationFrame((function(_this) {
          return function() {
            return _this.runLoop();
          };
        })(this));
      };

      return Cropper;

    })(Events);

    RodeoCrop.Cropper = Cropper;

    __exports__["default"] = RodeoCrop;
  });define("stage", 
  ["funderscore","drawing","events","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __exports__) {
    "use strict";
    var _ = __dependency1__["default"];
    var drawing = __dependency2__["default"];
    var Event = __dependency3__.Event;
    var Stage,
      __hasProp = {}.hasOwnProperty,
      __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

    Stage = (function(_super) {
      __extends(Stage, _super);

      function Stage(options) {
        Stage.__super__.constructor.call(this, options);
        this.canvas = options.canvas;
        this.lastMouseDownTarget = null;
        this.lastMouseMoveTarget = null;
        this.dragTarget = null;
        this.clickTarget = null;
        this.attachListeners();
      }

      Stage.prototype.bubbleMouseEvent = function(target, event, originalEvent, canvasPoint) {
        var eventObject;
        eventObject = new Event({
          target: target,
          originalEvent: originalEvent,
          canvasPoint: canvasPoint
        });
        return target.bubble(event, eventObject);
      };

      Stage.prototype.attachListeners = function() {
        this.canvas.addEventListener('mouseup', (function(_this) {
          return function(e) {
            var pos, target;
            if (e.which !== 1) {
              return;
            }
            pos = _this.windowToCanvas(e);
            target = _this.findChildAtPoint(pos) || _this;
            _this.bubbleMouseEvent(target, 'mouseup', e, pos);
            if (_this.clickTarget === target) {
              _this.bubbleMouseEvent(_this.clickTarget, 'click', e, pos);
            }
            _this.lastMouseDownTarget = null;
            _this.lastMouseMoveTarget = null;
            return _this.clickTarget = null;
          };
        })(this));
        this.canvas.addEventListener('mousedown', (function(_this) {
          return function(e) {
            var mouseMoveListener, mouseUpListener, pos, target;
            if (e.which !== 1) {
              return;
            }
            pos = _this.windowToCanvas(e);
            target = _this.findChildAtPoint(pos) || _this;
            _this.bubbleMouseEvent(target, 'mousedown', e, pos);
            _this.lastMouseDownTarget = target;
            _this.clickTarget = target;
            _this.movedSinceMouseDown = false;
            mouseMoveListener = function(e) {
              e.preventDefault();
              pos = _this.windowToCanvas(e);
              if (_this.lastMouseDownTarget) {
                if (!_this.dragTarget) {
                  _this.bubbleMouseEvent(_this.lastMouseDownTarget, 'dragstart', e, pos);
                  _this.dragTarget = _this.lastMouseDownTarget;
                }
                return _this.bubbleMouseEvent(_this.dragTarget, 'dragmove', e, pos);
              }
            };
            mouseUpListener = function(e) {
              e.preventDefault();
              if (_this.dragTarget) {
                pos = _this.windowToCanvas(e);
                _this.bubbleMouseEvent(_this.dragTarget, 'dragend', e, pos);
              }
              _this.lastMouseDownTarget = null;
              _this.lastMouseMoveTarget = null;
              _this.dragTarget = null;
              if (!_this.canvasContainsWindowPoint(e)) {
                _this.clickTarget = null;
              }
              window.removeEventListener('mousemove', mouseMoveListener);
              return window.removeEventListener('mouseup', mouseUpListener);
            };
            window.addEventListener('mousemove', mouseMoveListener);
            return window.addEventListener('mouseup', mouseUpListener);
          };
        })(this));
        this.canvas.addEventListener('mouseout', (function(_this) {
          return function(e) {
            var pos;
            pos = _this.windowToCanvas(e);
            if (_this.lastMouseMoveTarget) {
              return _this.bubbleMouseEvent(_this.lastMouseMoveTarget, 'mouseout', e, pos);
            }
          };
        })(this));
        return this.canvas.addEventListener('mousemove', (function(_this) {
          return function(e) {
            var pos, target;
            pos = _this.windowToCanvas(e);
            target = _this.findChildAtPoint(pos) || _this;
            _this.bubbleMouseEvent(target, 'mousemove', e, pos);
            if (target !== _this.lastMouseMoveTarget) {
              if (_this.lastMouseMoveTarget) {
                _this.bubbleMouseEvent(_this.lastMouseMoveTarget, 'mouseout', e, pos);
              }
              _this.bubbleMouseEvent(target, 'mouseover', e, pos);
            }
            return _this.lastMouseMoveTarget = target;
          };
        })(this));
      };

      Stage.prototype.canvasContainsWindowPoint = function(e) {
        var rect;
        rect = this.canvas.getBoundingClientRect();
        return e.clientX >= rect.left && e.clientX <= rect.right && e.clientY >= rect.top && e.clientY <= rect.bottom;
      };

      Stage.prototype.windowToCanvas = function(e) {
        var rect, x, y;
        rect = this.canvas.getBoundingClientRect();
        x = e.clientX - rect.left - parseInt(window.getComputedStyle(this.canvas).getPropertyValue('padding-left'), 0);
        y = e.clientY - rect.top - parseInt(window.getComputedStyle(this.canvas).getPropertyValue('padding-top'), 0);
        return {
          x: x,
          y: y
        };
      };

      Stage.prototype.frame = function() {
        return {
          x: 0,
          y: 0,
          w: this.canvas.width,
          h: this.canvas.height
        };
      };

      Stage.prototype.bounds = function() {
        return this.frame();
      };

      return Stage;

    })(drawing.Drawable);

    __exports__["default"] = Stage;
  });define("vendor/loader", 
  [],
  function() {
    "use strict";
    var define, requireModule, require, requirejs;

    (function() {
      var registry = {}, seen = {};

      define = function(name, deps, callback) {
        registry[name] = { deps: deps, callback: callback };
      };

      requirejs = require = requireModule = function(name) {
      requirejs._eak_seen = registry;

        if (seen.hasOwnProperty(name)) { return seen[name]; }
        seen[name] = {};

        if (!registry[name]) {
          throw new Error("Could not find module " + name);
        }

        var mod = registry[name],
            deps = mod.deps,
            callback = mod.callback,
            reified = [],
            exports;

        for (var i=0, l=deps.length; i<l; i++) {
          if (deps[i] === 'exports') {
            reified.push(exports = {});
          } else {
            reified.push(requireModule(resolve(deps[i])));
          }
        }

        var value = callback.apply(this, reified);
        return seen[name] = exports || value;

        function resolve(child) {
          if (child.charAt(0) !== '.') { return child; }
          var parts = child.split("/");
          var parentBase = name.split("/").slice(0, -1);

          for (var i=0, l=parts.length; i<l; i++) {
            var part = parts[i];

            if (part === '..') { parentBase.pop(); }
            else if (part === '.') { continue; }
            else { parentBase.push(part); }
          }

          return parentBase.join("/");
        }
      };
    })();
  });window.RodeoCrop = requireModule('rodeo-crop').default;
