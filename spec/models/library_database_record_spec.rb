# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/database_models_shared_examples'

RSpec.describe LibraryDatabaseRecord do
  context 'with shared examples' do
    let!(:database_record) do
      described_class.new_from_csv(
        ['2939016', 'Chosŏn Wangjo Sillok  = The Annals of the Joseon dynasty',
         'Free database of the annual record of the Joseon Dynasty of Korea. ' \
         'Available in the Hangul scripts as well as the original classical Chinese texts.',
         '', 'http://sillok.history.go.kr', 'https://libguides.princeton.edu/resource/4673', 'Korean Studies']
      )
    end
    let(:unaccented) { 'Choson Wangjo Sillok' }
    let(:precomposed) { 'Chosŏn wangjo sillok' }
    let(:decomposed) { 'Chosŏn wangjo sillok' }

    before do
      database_record
    end

    it_behaves_like('a database service')
  end

  describe '::new_from_csv' do
    it 'generates a new database record from the CSV row' do
      csv_data = ['123', 'Academic Search', 'A very good database',
                  'Academic Search Plus; Academic Search Premier',
                  'http://ebsco.com',
                  'https://libguides.princeton.edu/resource/12345',
                  'Civil Engineering;Energy;Environment']
      described_class.new_from_csv(csv_data)
      record = described_class.last
      expect(record.libguides_id).to eq(123)
      expect(record.name).to eq('Academic Search')
      expect(record.description).to eq('A very good database')
      expect(record.alt_names).to contain_exactly('Academic Search Plus', 'Academic Search Premier')
      expect(record.url).to eq('http://ebsco.com')
      expect(record.friendly_url).to eq('https://libguides.princeton.edu/resource/12345')
      expect(record.subjects).to contain_exactly('Civil Engineering', 'Energy', 'Environment')
    end
  end

  describe 'query scope' do
    let(:doc1) do
      described_class.create(name: 'Resource',
                             alt_names_concat: 'EBSCO; JSTOR',
                             libguides_id: 1,
                             description: 'Great database',
                             subjects_concat: 'Electrical engineering;Computer science')
    end

    it 'finds exact matches in the description field' do
      expect(described_class.query('Great database')).to contain_exactly(doc1)
    end

    it 'finds case-insensitive matches in the description field' do
      expect(described_class.query('great database')).to contain_exactly(doc1)
    end

    it 'finds partial matches in the description field' do
      expect(described_class.query('great')).to contain_exactly(doc1)
    end

    it 'finds singular versions of plural search terms' do
      expect(described_class.query('databases')).to contain_exactly(doc1)
    end

    it 'finds exact matches in the subject_concat field' do
      expect(described_class.query('Computer science')).to contain_exactly(doc1)
    end

    it 'can negate searches with -' do
      expect(described_class.query('Computer -science')).to be_empty
    end

    it 'finds stemmed matches in the subject_concat field' do
      expect(described_class.query('computation')).to contain_exactly(doc1)
    end

    it 'finds matches in the title field' do
      expect(described_class.query('resource')).to contain_exactly(doc1)
    end

    it 'finds matches in the alt_names_concat field' do
      expect(described_class.query('jstor')).to contain_exactly(doc1)
    end
  end

  context 'with fixture file loaded' do
    let(:libjobs_response) { file_fixture('libjobs/library-databases.csv') }

    before do
      stub_request(:get, 'https://lib-jobs.princeton.edu/library-databases.csv')
        .to_return(status: 200, body: libjobs_response)
      LibraryDatabaseLoadingService.new.run
    end

    it 'matches the current expected search' do
      query_response = described_class.query('oxford music')
      expect(query_response[0].name).to eq('Oxford Music Online')
      expect(query_response[1].name).to eq('Oxford Scholarship Online:  Music')
      expect(query_response[2].name).to eq('Oxford Bibliographies: Music')
    end

    it 'is safe from sql injection' do
      bad_string = "'))); DROP TABLE library_database_records;"
      expect do
        described_class.query(bad_string)
      end.not_to(change(described_class, :count))
    end

    context 'with Japanese text using differently composed characters' do
      let(:precomposed) { 'Kōbunsō Taika Koshomoku' }
      let(:no_accents) { 'Kobunso Taika Koshomoku' }
      let(:decomposed) { 'Kōbunsō Taika Koshomoku' }

      it 'finds the title regardless of composition' do
        result1 = described_class.query(precomposed)
        expect(result1.size).to eq(1)
        result2 = described_class.query(no_accents)
        expect(result2.size).to eq(1)
        result3 = described_class.query(decomposed)
        expect(result3.size).to eq(1)
      end
    end

    context 'with a glottal stop character' do
      let(:query_terms) { 'Maʻagarim' }

      it 'finds the database' do
        result1 = described_class.query(query_terms)
        expect { described_class.query(query_terms) }.not_to raise_error
        expect(result1.size).to eq(1)
      end
    end
  end
end
