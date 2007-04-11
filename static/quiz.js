Object.extend(Array.prototype, {
  swap: function(i,j) {
    ti = this[i];
    this[i] = this[j];
    this[j] = ti;
  },
  
  randomize: function() {
    var i = this.length;
    while (--i) {
      var j = parseInt(Math.random() * i);
      this.swap(i,j); 
    }
    return this;
  }
});

var Quiz = Class.create();
Quiz.prototype = {
  initialize: function(pegs, container, options) {
    this.pegs = pegs;
    
    this.options = options;
    this.container = $(container);

    this.buttons = document.createElement("DIV");
    this.buttons.id = "buttons";
    
    this.next_button = document.createElement("INPUT");
    this.next_button.type = "button";
    this.next_button.value = "Next";

    this.flip_button = document.createElement("INPUT");
    this.flip_button.type = "button";
    this.flip_button.value = "Flip";
    
    this.instructions = document.createElement("SPAN");
    this.instructions.innerHTML = "<br/>Hit space bar to flip then next"
    
    Event.observe(this.flip_button, 'click', this.flip.bindAsEventListener(this))
    Event.observe(this.next_button, 'click', this.next.bindAsEventListener(this))

    this.buttons.appendChild(this.next_button);
    this.buttons.appendChild(this.flip_button);
    this.buttons.appendChild(this.instructions);
    
    Event.observe(document, 'keyup', this.keyHandler.bindAsEventListener(this))
    
    this.loadImages();
    
    this.start();
  },
  
  start: function() {
    this.current = 0;
    this.pegs = this.pegs.randomize();
    this.container.innerHTML = "";
    this.flip();
  },
  
  keyHandler: function(e) {
    var key = String.fromCharCode(e.keyCode)
    switch (key) {
      case "P":
        this.previous();
        break;
      case "N":
        this.next();
        break;
      case "F":
        this.flip();
        break;
      case " ":
      case "G":
        this.go();
        break;
      case "R":
        this.start();
    }
  },
  
  loadImages: function() {
    var ims = [];
    var i = 0;
    this.pegs.each(function(peg) {
      ims[++i] = new Image()
      ims[i].src = peg.attributes.image_url;
    })
  },

  go: function() {
    if (this.container.innerHTML.match(/Peg number/)) {
      this.flip();
    }
    else {
      this.next();
    }
  },
  
  previous: function() {
    this.current--;
    if (this.current < 0) this.current = this.pegs.length;
    this.container.innerHTML = "";
    this.flip();
  },
  
  next: function() {
    this.current++;
    if (this.current >= this.pegs.length) {
      this.current = 0;
      this.pegs = this.pegs.randomize;
    }
    this.container.innerHTML = "";
    this.flip();
  },
  
  flip: function() {
    if (this.container.innerHTML.match(/Peg number/)) {
      this.container.innerHTML = "";
      
      var h1 = document.createElement("H1");
      h1.innerHTML = this.pegs[this.current].attributes.phrase;
      
      var div = document.createElement("DIV");
      div.id = "images";
      div.innerHTML = "<img src='" + this.pegs[this.current].attributes.image_url + "'>"
      
      this.container.appendChild(div);
      this.container.appendChild(h1);
    }
    else {
      this.container.innerHTML = "";
      var h2 = document.createElement("H2");
      h2.innerHTML = "Peg number"
      
      var h1 = document.createElement("H1");
      h1.innerHTML = this.pegs[this.current].attributes.number;
      
      this.container.appendChild(h2);
      this.container.appendChild(h1);
    }
    
    this.container.appendChild(this.buttons);    
  }
}