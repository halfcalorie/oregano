require 'oregano/gettext/config'
require 'spec_helper'

describe Oregano::GettextConfig do
  require 'oregano_spec/files'
  include OreganoSpec::Files

  let(:local_path) do
    local_path ||= Oregano::GettextConfig::LOCAL_PATH
  end

  let(:windows_path) do
    windows_path ||= Oregano::GettextConfig::WINDOWS_PATH
  end

  let(:posix_path) do
    windows_path ||= Oregano::GettextConfig::POSIX_PATH
  end

  describe 'translation mode selection' do
    it 'should select PO mode when given a local config path' do
      expect(Oregano::GettextConfig.translation_mode(local_path)).to eq(:po)
    end

    it 'should select PO mode when given a non-package config path' do
      expect(Oregano::GettextConfig.translation_mode('../fake/path')).to eq(:po)
    end

    it 'should select MO mode when given a Windows package config path' do
      expect(Oregano::GettextConfig.translation_mode(windows_path)).to eq(:mo)
    end

    it 'should select MO mode when given a POSIX package config path' do
      expect(Oregano::GettextConfig.translation_mode(posix_path)).to eq(:mo)
    end
  end

  describe 'initialization' do
    context 'when given a nil config path' do
      it 'should return false' do
        expect(Oregano::GettextConfig.initialize(nil, :po)).to be false
      end
    end

    context 'when given a valid config file location' do
      it 'should return true' do
        expect(Oregano::GettextConfig.initialize(local_path, :po)).to be true
      end
    end

    context 'when given a bad file format' do
      it 'should raise an exception' do
        expect { Oregano::GettextConfig.initialize(local_path, :bad_format) }.to raise_error(Oregano::Error)
      end
    end
  end
end
