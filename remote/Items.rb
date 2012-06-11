require 'wcnh'

module Items
  PennJSON::register_object(self)
  R = PennJSON::Remote
  
  def self.pj_get_attr(dbref, attr)
    self.get_attr(dbref, attr)
  end
  
  def self.pj_list(kind=nil)
    self.list(kind)
  end

  def self.pj_create(type)
    self.create(type)
  end

  def self.pj_set_attr(dbref, attr, value=nil)
    self.set_attr(dbref, attr, value)
  end

  def self.pj_edit(num, field, value=nil)
    self.edit(num, field, value)
  end

  def self.pj_destroy(num)
    self.destroy(num)
  end

  def self.pj_new(kind)
    self.new(kind)
  end

  def self.pj_view(num)
    self.view(num)
  end

  def self.pj_vendor_purchase(vendor, item)
    self.vendor_purchase(vendor, item)
  end

  def self.pj_vendor_list(vendor)
    self.vendor_list(vendor)
  end

  def self.pj_vendor_stock(vendor, item, amount)
    self.vendor_stock(vendor, item, amount)
  end
end