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
    this.current = 0;
    
    this.options = options;
    this.container = $(container);
    this.pegs = pegs.randomize();

    this.next_button = document.createElement("INPUT");
    this.next_button.type = "button";
    this.next_button.value = "Next";

    this.flip_button = document.createElement("INPUT");
    this.flip_button.type = "button";
    this.flip_button.value = "Flip";
    
    Event.observe(this.flip_button, 'click', function() { this.flip(); }.bind(this))
    Event.observe(this.next_button, 'click', function() { this.next(); }.bind(this))
    
    this.loadImages();
    this.flip();
  },
  
  loadImages: function() {
    this.pegs.each(function(peg) {
      var im = new Image()
      im.src = peg.attributes.image_url;
      console.log(im.src)
    })
  },
  
  next: function() {
    this.current++;
    if (this.current >= this.pegs.length) this.current = 0;
    this.container.innerHTML = "";
    this.flip();
  },
  
  flip: function() {
    if (this.container.innerHTML.match(/Peg number/)) {
      this.container.innerHTML = "";
      
      var h2 = document.createElement("H2");
      h2.innerHTML = this.pegs[this.current].attributes.phrase;
      
      var div = document.createElement("DIV");
      div.innerHTML = "<img src='" + this.pegs[this.current].attributes.image_url + "'>"
      
      this.container.appendChild(h2);
      this.container.appendChild(div);
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
    
    this.container.appendChild(this.next_button);
    this.container.appendChild(this.flip_button);
    
  }
}