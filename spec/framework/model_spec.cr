require "../spec_helper"

class FooBarModel
  include Balloon::Model

  @[Persistent]
  property foo : String?
  validates foo do
    # no op
  end

  @[Persistent]
  property bar : String?
  validates bar do
    # no op
  end

  @[Persistent]
  property not_nil_model_id : Int64?

  belongs_to not_nil_model
  has_one not_nil, class_name: NotNilModel

  @[Persistent]
  property body_json : String?

  serializes body

  class Body
    JSON.mapping(
      body: Float64
    )

    def initialize(@body)
    end
  end
end

class NotNilModel
  include Balloon::Model

  @[Persistent]
  property key : String = "Key"
  validates key { "is not capitalized" unless key.starts_with?(/[A-Z]/) }

  @[Persistent]
  property val : String
  validates val { "is not capitalized" unless val.starts_with?(/[A-Z]/) }

  def validate
    super
    @errors["instance"] = ["key is equal to val"] if key == val
    @errors
  end

  @[Persistent]
  property foo_bar_model_id : Int64?

  belongs_to foo_bar, class_name: FooBarModel, foreign_key: foo_bar_model_id
  has_many foo_bar_models

  @[Persistent]
  property body_yaml : String?

  serializes body, format: yaml

  class Body
    YAML.mapping(
      body: Float64
    )

    def initialize(@body)
    end
  end
end

Spectator.describe Balloon::Model::Utils do
  describe ".table_name" do
    it "returns the table name" do
      expect(described_class.table_name(Time::Span)).to eq("time_spans")
      expect(described_class.table_name(SemanticVersion)).to eq("semantic_versions")
      expect(described_class.table_name(Process)).to eq("processes")
    end
  end
end

Spectator.describe Balloon::Model do
  before_each do
    Balloon.database.exec <<-SQL
      CREATE TABLE foo_bar_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        created_at datetime,
        updated_at datetime,
        not_nil_model_id integer,
        body_json text,
        foo text,
        bar text
      )
    SQL
    Balloon.database.exec <<-SQL
      CREATE TABLE not_nil_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        created_at datatime,
        updated_at datetime,
        foo_bar_model_id integer,
        body_yaml text,
        key text NOT NULL,
        val text NOT NULL
      )
    SQL
  end
  after_each do
    Balloon.database.exec "DROP TABLE foo_bar_models"
    Balloon.database.exec "DROP TABLE not_nil_models"
  end

  describe ".new" do
    it "creates a new instance" do
      expect(FooBarModel.new.foo).to be_nil
    end

    it "creates a new instance" do
      expect(NotNilModel.new(val: "Val").val).to eq("Val")
    end
  end

  describe "#assign" do
    it "bulk assigns properties" do
      expect(FooBarModel.new.assign(foo: "Foo").foo).to eq("Foo")
    end

    it "bulk assigns properties" do
      expect(NotNilModel.new(val: "").assign(val: "Val").val).to eq("Val")
    end
  end

  describe "#==" do
    it "returns true if all properties are equal" do
      a = FooBarModel.new(foo: "Foo")
      b = FooBarModel.new(foo: "Foo")
      expect(a).to eq(b)
    end

    it "returns true if all properties are equal" do
      a = NotNilModel.new(val: "Val")
      b = NotNilModel.new(val: "Val")
      expect(a).to eq(b)
    end
  end

  describe ".empty?" do
    it "returns true" do
      expect(FooBarModel.empty?).to be_true
    end

    it "returns true" do
      expect(NotNilModel.empty?).to be_true
    end
  end

  describe ".count" do
    before_each do
      FooBarModel.new.save
      NotNilModel.new(val: "Val").save
    end

    it "returns the count of persisted instances" do
      expect(FooBarModel.count).to eq(1)
    end

    it "returns the count of matching instances" do
      expect(FooBarModel.count(foo: "")).to eq(0)
    end

    it "returns the count of persisted instances" do
      expect(NotNilModel.count).to eq(1)
    end

    it "returns the count of matching instances" do
      expect(NotNilModel.count(val: "")).to eq(0)
    end
  end

  describe ".all" do
    it "returns all persisted instances" do
      saved_model = FooBarModel.new.save
      expect(FooBarModel.all).to eq([saved_model])
    end

    it "returns all persisted instances" do
      saved_model = NotNilModel.new(val: "Val").save
      expect(NotNilModel.all).to eq([saved_model])
    end
  end

  describe ".find" do
    context "given the id" do
      it "finds the saved instance" do
        saved_model = FooBarModel.new.save
        expect(FooBarModel.find(saved_model.id)).not_to be(saved_model)
        expect(FooBarModel.find(saved_model.id)).to eq(saved_model)
      end

      it "finds the updated instance" do
        updated_model = FooBarModel.new.save.save
        expect(FooBarModel.find(updated_model.id)).not_to be(updated_model)
        expect(FooBarModel.find(updated_model.id)).to eq(updated_model)
      end

      it "finds the saved instance" do
        saved_model = NotNilModel.new(val: "Val").save
        expect(NotNilModel.find(saved_model.id)).not_to be(saved_model)
        expect(NotNilModel.find(saved_model.id)).to eq(saved_model)
      end

      it "raises an exception" do
        expect{NotNilModel.find(999999)}.to raise_error(Balloon::Model::NotFound)
      end
    end

    context "given properties" do
      it "finds the saved instance" do
        saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
        expect(FooBarModel.find(foo: "Foo")).not_to be(saved_model)
        expect(FooBarModel.find(foo: "Foo")).to eq(saved_model)
      end

      it "finds the updated instance" do
        updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
        expect(FooBarModel.find(foo: "Bar")).not_to be(updated_model)
        expect(FooBarModel.find(foo: "Bar")).to eq(updated_model)
      end

      it "finds the saved instance" do
        saved_model = NotNilModel.new(val: "Val").save
        expect(NotNilModel.find(val: "Val")).not_to be(saved_model)
        expect(NotNilModel.find(val: "Val")).to eq(saved_model)
      end

      it "raises an exception" do
        expect{NotNilModel.find(val: "Baz")}.to raise_error(Balloon::Model::NotFound)
      end
    end
  end

  describe ".where" do
    it "returns the saved instances" do
      saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
      expect(FooBarModel.where(foo: "Foo")).to eq([saved_model])
      expect(FooBarModel.where(foo: "Bar")).to be_empty
    end

    it "returns the saved instances" do
      saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
      expect(FooBarModel.where("foo = ?", "Foo")).to eq([saved_model])
      expect(FooBarModel.where("foo = ?", "Bar")).to be_empty
    end

    it "returns the updated instances" do
      updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
      expect(FooBarModel.where(foo: "Bar")).to eq([updated_model])
      expect(FooBarModel.where(foo: "Foo")).to be_empty
    end

    it "returns the updated instances" do
      updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
      expect(FooBarModel.where("foo = ?", "Bar")).to eq([updated_model])
      expect(FooBarModel.where("foo = ?", "Foo")).to be_empty
    end

    it "returns the saved instances" do
      saved_model = NotNilModel.new(val: "Val").save
      expect(NotNilModel.where(val: "Val")).to eq([saved_model])
      expect(NotNilModel.where(val: "")).to be_empty
    end

    it "returns the saved instances" do
      saved_model = NotNilModel.new(val: "Val").save
      expect(NotNilModel.where("val = ?", "Val")).to eq([saved_model])
      expect(NotNilModel.where("val = ?", "")).to be_empty
    end
  end

  describe "#valid?" do
    it "performs the validations" do
      new_model = NotNilModel.new(key: "Test", val: "Test")
      expect(new_model.valid?).to be_false
      expect(new_model.errors).to eq({"instance" => ["key is equal to val"]})
    end

    it "performs the validations" do
      new_model = NotNilModel.new(key: "key", val: "val")
      expect(new_model.valid?).to be_false
      expect(new_model.errors).to eq({"key" => ["is not capitalized"], "val" => ["is not capitalized"]})
    end

    it "performs the validations" do
      new_model = NotNilModel.new(key: "Key", val: "Val")
      expect(new_model.valid?).to be_true
      expect(new_model.errors).to be_empty
    end
  end

  describe "#save" do
    context "new instance" do
      it "saves a new instance" do
        expect{FooBarModel.new.save}.to change{FooBarModel.count}.by(1)
      end

      it "assigns an id" do
        new_model = FooBarModel.new
        expect{new_model.save}.to change{new_model.id}
      end

      it "raises an exception" do
        new_model = NotNilModel.new(val: "")
        expect{new_model.save}.to raise_error(Balloon::Model::Invalid)
        expect(new_model.errors).not_to be_empty
      end

      it "saves the properties" do
        saved_model = FooBarModel.new(foo: "Foo", bar: "Bar").save
        expect(FooBarModel.find(saved_model.id).foo).to eq("Foo")
        expect(FooBarModel.find(saved_model.id).bar).to eq("Bar")
      end

      it "saves the properties" do
        saved_model = NotNilModel.new(val: "Val").save
        expect(NotNilModel.find(saved_model.id).val).to eq("Val")
      end
    end

    context "existing instance" do
      it "does not save a new instance" do
        expect{FooBarModel.new.save.save}.to change{FooBarModel.count}.by(1)
      end

      it "does not assign an id" do
        saved_model = FooBarModel.new.save
        expect{saved_model.save}.not_to change{saved_model.id}
      end

      it "raises an exception" do
        new_model = NotNilModel.new(val: "Val").save
        expect{new_model.assign(val: "").save}.to raise_error(Balloon::Model::Invalid)
        expect(new_model.errors).not_to be_empty
      end

      it "updates the properties" do
        updated_model = FooBarModel.new(foo: "Foo", bar: "Bar").save.assign(foo: "Bar").save
        expect(FooBarModel.find(updated_model.id).foo).to eq("Bar")
        expect(FooBarModel.find(updated_model.id).bar).to eq("Bar")
      end

      it "updates the properties" do
        updated_model = NotNilModel.new(val: "Val").save.assign(val: "Baz").save
        expect(NotNilModel.find(updated_model.id).val).to eq("Baz")
      end
    end
  end

  describe "#destroy" do
    it "destroys the persisted instance" do
      saved_model = FooBarModel.new.save
      expect{saved_model.destroy}.to change{FooBarModel.count}.by(-1)
    end
  end

  describe "#to_json" do
    it "returns the JSON representation" do
      saved_model = FooBarModel.new
      expect(saved_model.to_json).to match(/"id":null/)
    end
  end

  describe "#to_s" do
    it "returns the string representation" do
      saved_model = FooBarModel.new
      expect(saved_model.to_s).to match(/id=nil/)
    end
  end

  describe "#to_h" do
    it "returns the hash representation" do
      saved_model = FooBarModel.new
      expect(saved_model.to_h.to_a).to contain({"id", nil})
    end
  end

  context "associations" do
    let(foo_bar) { FooBarModel.new.save }
    let(not_nil) { NotNilModel.new(val: "Val").save }

    before_each do
      foo_bar.assign(not_nil_model_id: not_nil.id).save
      not_nil.assign(foo_bar_model_id: foo_bar.id).save
    end

    it "assigns the associated instance" do
      expect(foo_bar.not_nil_model = not_nil).to eq(not_nil)
      expect(foo_bar.not_nil_model).to eq(not_nil)
    end

    it "assigns the associated instance" do
      expect(not_nil.foo_bar = foo_bar).to eq(foo_bar)
      expect(not_nil.foo_bar).to eq(foo_bar)
    end

    it "gets the associated instance" do
      expect(foo_bar.not_nil).to eq(not_nil)
    end

    it "gets the associated instance" do
      expect(not_nil.foo_bar_models).to eq([foo_bar])
    end
  end

  context "serializations" do
    let(foo_bar) { FooBarModel.new }
    let(not_nil) { NotNilModel.new(val: "Val") }

    it "serializes body as JSON" do
      foo_bar.body = FooBarModel::Body.new(13.0)
      expect(foo_bar.body_json).to eq("{\"body\":13.0}")
      expect(foo_bar.body).to be_a(FooBarModel::Body)
    end

    it "serializes body as YAML" do
      not_nil.body = NotNilModel::Body.new(17.0)
      expect(not_nil.body_yaml).to eq("---\nbody: 17.0\n")
      expect(not_nil.body).to be_a(NotNilModel::Body)
    end
  end
end
