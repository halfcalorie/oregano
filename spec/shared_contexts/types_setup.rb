shared_context 'types_setup' do

  # Do not include the special type Unit in this list
  def self.all_types
    [ Oregano::Pops::Types::PAnyType,
      Oregano::Pops::Types::PUndefType,
      Oregano::Pops::Types::PNotUndefType,
      Oregano::Pops::Types::PScalarType,
      Oregano::Pops::Types::PScalarDataType,
      Oregano::Pops::Types::PStringType,
      Oregano::Pops::Types::PNumericType,
      Oregano::Pops::Types::PIntegerType,
      Oregano::Pops::Types::PFloatType,
      Oregano::Pops::Types::PRegexpType,
      Oregano::Pops::Types::PBooleanType,
      Oregano::Pops::Types::PCollectionType,
      Oregano::Pops::Types::PArrayType,
      Oregano::Pops::Types::PHashType,
      Oregano::Pops::Types::PIterableType,
      Oregano::Pops::Types::PIteratorType,
      Oregano::Pops::Types::PRuntimeType,
      Oregano::Pops::Types::PClassType,
      Oregano::Pops::Types::PResourceType,
      Oregano::Pops::Types::PPatternType,
      Oregano::Pops::Types::PEnumType,
      Oregano::Pops::Types::PVariantType,
      Oregano::Pops::Types::PStructType,
      Oregano::Pops::Types::PTupleType,
      Oregano::Pops::Types::PCallableType,
      Oregano::Pops::Types::PTypeType,
      Oregano::Pops::Types::POptionalType,
      Oregano::Pops::Types::PDefaultType,
      Oregano::Pops::Types::PTypeReferenceType,
      Oregano::Pops::Types::PTypeAliasType,
      Oregano::Pops::Types::PSemVerType,
      Oregano::Pops::Types::PSemVerRangeType,
      Oregano::Pops::Types::PTimespanType,
      Oregano::Pops::Types::PTimestampType,
      Oregano::Pops::Types::PSensitiveType,
      Oregano::Pops::Types::PBinaryType,
      Oregano::Pops::Types::PInitType
    ]
  end
  def all_types
    self.class.all_types
  end

  def self.abstract_types
    [ Oregano::Pops::Types::PAnyType,
      Oregano::Pops::Types::PCallableType,
      Oregano::Pops::Types::PEnumType,
      Oregano::Pops::Types::PClassType,
      Oregano::Pops::Types::PDefaultType,
      Oregano::Pops::Types::PCollectionType,
      Oregano::Pops::Types::PInitType,
      Oregano::Pops::Types::PIterableType,
      Oregano::Pops::Types::PIteratorType,
      Oregano::Pops::Types::PNotUndefType,
      Oregano::Pops::Types::PResourceType,
      Oregano::Pops::Types::PRuntimeType,
      Oregano::Pops::Types::POptionalType,
      Oregano::Pops::Types::PPatternType,
      Oregano::Pops::Types::PScalarType,
      Oregano::Pops::Types::PScalarDataType,
      Oregano::Pops::Types::PVariantType,
      Oregano::Pops::Types::PUndefType,
      Oregano::Pops::Types::PTypeReferenceType,
      Oregano::Pops::Types::PTypeAliasType,
    ]
  end
  def abstract_types
    self.class.abstract_types
  end

  # Internal types. Not meaningful in pp
  def self.internal_types
    [ Oregano::Pops::Types::PTypeReferenceType,
      Oregano::Pops::Types::PTypeAliasType,
    ]
  end
  def internal_types
    self.class.internal_types
  end


  def self.scalar_data_types
    # PVariantType is also scalar data, if its types are all ScalarData
    [
      Oregano::Pops::Types::PScalarDataType,
      Oregano::Pops::Types::PStringType,
      Oregano::Pops::Types::PNumericType,
      Oregano::Pops::Types::PIntegerType,
      Oregano::Pops::Types::PFloatType,
      Oregano::Pops::Types::PBooleanType,
      Oregano::Pops::Types::PEnumType,
      Oregano::Pops::Types::PPatternType,
    ]
  end
  def scalar_data_types
    self.class.scalar_data_types
  end


  def self.scalar_types
    # PVariantType is also scalar, if its types are all Scalar
    [
      Oregano::Pops::Types::PScalarType,
      Oregano::Pops::Types::PScalarDataType,
      Oregano::Pops::Types::PStringType,
      Oregano::Pops::Types::PNumericType,
      Oregano::Pops::Types::PIntegerType,
      Oregano::Pops::Types::PFloatType,
      Oregano::Pops::Types::PRegexpType,
      Oregano::Pops::Types::PBooleanType,
      Oregano::Pops::Types::PPatternType,
      Oregano::Pops::Types::PEnumType,
      Oregano::Pops::Types::PSemVerType,
      Oregano::Pops::Types::PTimespanType,
      Oregano::Pops::Types::PTimestampType,
    ]
  end
  def scalar_types
    self.class.scalar_types
  end

  def self.numeric_types
    # PVariantType is also numeric, if its types are all numeric
    [
      Oregano::Pops::Types::PNumericType,
      Oregano::Pops::Types::PIntegerType,
      Oregano::Pops::Types::PFloatType,
    ]
  end
  def numeric_types
    self.class.numeric_types
  end

  def self.string_types
    # PVariantType is also string type, if its types are all compatible
    [
      Oregano::Pops::Types::PStringType,
      Oregano::Pops::Types::PPatternType,
      Oregano::Pops::Types::PEnumType,
    ]
  end
  def string_types
    self.class.string_types
  end

  def self.collection_types
    # PVariantType is also string type, if its types are all compatible
    [
      Oregano::Pops::Types::PCollectionType,
      Oregano::Pops::Types::PHashType,
      Oregano::Pops::Types::PArrayType,
      Oregano::Pops::Types::PStructType,
      Oregano::Pops::Types::PTupleType,
    ]
  end
  def collection_types
    self.class.collection_types
  end

  def self.data_compatible_types
    tf = Oregano::Pops::Types::TypeFactory
    result = scalar_data_types
    result << Oregano::Pops::Types::PArrayType.new(tf.data)
    result << Oregano::Pops::Types::PHashType.new(Oregano::Pops::Types::PStringType::DEFAULT, tf.data)
    result << Oregano::Pops::Types::PUndefType
    result << Oregano::Pops::Types::PTupleType.new([tf.data])
    result
  end
  def data_compatible_types
    self.class.data_compatible_types
  end

  def self.rich_data_compatible_types
    tf = Oregano::Pops::Types::TypeFactory
    result = scalar_types
    result << Oregano::Pops::Types::PArrayType.new(tf.rich_data)
    result << Oregano::Pops::Types::PHashType.new(tf.rich_data_key, tf.rich_data)
    result << Oregano::Pops::Types::PUndefType
    result << Oregano::Pops::Types::PDefaultType
    result << Oregano::Pops::Types::PTupleType.new([tf.rich_data])
    result
  end
  def rich_data_compatible_types
    self.class.rich_data_compatible_types
  end

  def self.type_from_class(c)
    c.is_a?(Class) ? c::DEFAULT : c
  end
  def type_from_class(c)
    self.class.type_from_class(c)
  end
end
