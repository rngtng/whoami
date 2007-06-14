DoubleSlider = Class.create();

DoubleSlider.prototype = {
	initialize: function(params) {
		var double_slider = this;
		
		this.container = params.container;
		this.clip_left = params.clip_left;
		this.clip_right = params.clip_right;
		this.handle_min = params.handle_min;
		this.handle_max = params.handle_max;
		
		this.container.style.overflow = "hidden";
		this.container.style.position = "relative";
				
		this.clip_left.style.position = "absolute";
		this.clip_left.style.width = "100%";
		this.clip_left.style.height = "100%";
		this.clip_left.style.left = (parseInt(this.handle_min.style.width) - parseInt(this.container.style.width)) + "px";

		this.clip_right.style.position = "absolute";
		this.clip_right.style.width = "100%";
		this.clip_right.style.height = "100%";
		this.clip_right.style.left = (parseInt(this.container.style.width) - parseInt(this.handle_max.style.width)) + "px";
		
		this.handle_max.style.cssFloat = "left";
		this.handle_min.style.cssFloat = "right";
		
		this.range = params.range || [0,1];
		this.change = params.change || function(r) {
			// do nothing
		};

		this.slide = params.slide || function(r) {
			// do nothing
		};
		
		new Draggable(params.clip_left, {
			handle: params.handle_min,
			constraint: 'horizontal',
			snap: function(x,y) {
				var clip_right_bound = parseInt(params.clip_right.style.left) - parseInt(params.container.style.width);
				var border_bound = parseInt(params.handle_min.style.width) - parseInt(params.container.style.width);
				if(x < border_bound) {
					x = border_bound;
				} else if(x > clip_right_bound) {
					x = clip_right_bound;
				}
				double_slider.slide(double_slider.getRange());
				return [x,y];
			},
			revert: function() {
				double_slider.change(double_slider.getRange());
			}
		});
		new Draggable(params.clip_right, {
			handle: params.handle_max,
			constraint: 'horizontal',
			snap: function(x,y) {
				var clip_left_bound = parseInt(params.clip_left.style.left) + parseInt(params.container.style.width);
				var border_bound = parseInt(params.container.style.width) - parseInt(params.handle_max.style.width);
				if(x > border_bound) {
					x = border_bound;
				} else if (x < clip_left_bound) {
					x = clip_left_bound;
				}
				double_slider.slide(double_slider.getRange());
				return [x,y];
			},
			revert: function() {
				double_slider.change(double_slider.getRange());
			}
		});

	},
	getRange: function() {
		var left = (parseInt(this.clip_left.style.left) + parseInt(this.container.style.width)); // - parseInt(this.handle_min.style.width));
		var right = parseInt(this.clip_right.style.left); // + parseInt(this.handle_max.style.width);
		return [this.pixelToReal(left), this.pixelToReal(right)];
	},	
	setRange: function(min, max) {
		// alert(min + ", " + max);
		var left_left = (this.realToPixel(min) - parseInt(this.container.style.width)) + "px";
		var right_left = this.realToPixel(max) + "px";
		this.clip_left.style.left = left_left;
		this.clip_right.style.left = right_left;
	},
	pixelToReal: function(pixel) {
		var conversion_factor = (this.range[1] - this.range[0])/(parseInt(this.container.style.width) - parseInt(this.handle_min.style.width) - parseInt(this.handle_max.style.width));
		return (((pixel - parseInt(this.handle_min.style.width))*conversion_factor) + this.range[0]);
	},
	realToPixel: function(real) {
		var conversion_factor = (parseInt(this.container.style.width) - parseInt(this.handle_min.style.width) - parseInt(this.handle_max.style.width))/(this.range[1] - this.range[0]);
		// alert(conversion_factor);
		return ((real-this.range[0])*conversion_factor + parseInt(this.handle_min.style.width));
	}
	
}
