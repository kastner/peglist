var ImagePanel = Class.create();
ImagePanel.prototype = {
  initialize: function(images, container, options) {
    this.options = options;
    this.container = $(container);
    this.images = images;
    
    this.position = 0;
    this.per_page = 6;
    
    this.image_list = document.getElementsByClassName("image_list", this.container)[0];
    this.down_button = document.getElementsByClassName("image_button", this.container)[0];
    this.up_button = document.getElementsByClassName("image_button", this.container)[1];
    
    Event.observe(this.up_button, 'click', function() { this.up(); }.bind(this))
    Event.observe(this.down_button, 'click', function() { this.down(); }.bind(this))
    
    this.loadImages();
  },
  
  loadImages: function() {
    var i = 0;
    this.image_list.innerHTML = '';
    this.images.forEach(function(image) {
      console.log("pos: " + this.position + "/ i:" + i + " / per:" + this.per_page + " / length:" + this.images.length)
      if (i >= this.position && i < this.position + this.per_page) {
        //new Insertion.Bottom(this.image_list, this.image(image));
        this.image_list.appendChild(this.image(image));
      }
      i++;
    }.bind(this))
  },
  
  image: function(image) {
    var url = "http://farm" + image.farm + ".static.flickr.com/" + image.server + "/" + image.id + "_" + image.secret + "_s.jpg";
    var link = "http://www.flickr.com/photos/" + image.user_id + "/" + image.id
    img = document.createElement("IMG")
    img.src = url;
    img.rel = link;
    Event.observe(img, 'click', function(e) {
      console.log(this.image_list);
      ele = Event.element(e);
      
      var sels = document.getElementsByClassName("selected", this.image_list);
      if (sels.length > 0) { sels.invoke("removeClassName", "selected"); }
      
      ele.addClassName("selected");
      
      $(this.options.src).value = ele.src;
      $(this.options.link).value = ele.rel;
    }.bind(this))
    return img;
  },
  
  up: function() {
    this.position += this.per_page;
    if (this.position >= this.images.length) { this.position = 0; }
    this.loadImages();
  },
  
  down: function() {
    this.position -= this.per_page;
    if (this.position < 0) { this.position = this.images.length - this.per_page; }
    this.loadImages();
  }
}
