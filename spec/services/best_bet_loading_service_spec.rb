# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BestBetLoadingService do
  let(:google_response) { file_fixture('google_sheets/best_bets.csv') }

  before do
    stub_request(:get, 'https://docs.google.com/spreadsheets/d/e/2PACX-1vSSDYbAmj_SDVK96DJItSsir_PbjMIqe8cBMvBfRIh4fpVzv3aozhCdulrgJXZzwl-fh-lbULMuLZuO/pub?gid=170493948&single=true&output=csv')
      .to_return(status: 200, body: google_response)
  end

  it 'creates a new row in the best_bet table for each CSV row' do
    expect { described_class.new.run }.to change(BestBetDocument, :count).by(3)
    expect(BestBetDocument.third.title).to eq('Access and Borrowing')
    expect(BestBetDocument.third.description).to eq('Information on access and borrowing privileges ' \
                                                    'for different categories of library patrons, espec')
    expect(BestBetDocument.third.url).to eq('https://library.princeton.edu/services/access')
    expect(BestBetDocument.third.search_terms).to contain_exactly('access', 'access office', 'privileges',
                                                                  'privileges office', 'visitors')
    expect(BestBetDocument.third.last_update).to eq(Date.new(2021, 7, 8))
  end

  it 'is idempotent' do
    described_class.new.run
    expect { described_class.new.run }.not_to change(BestBetDocument, :count)
  end

  context 'when file does not have the required headers' do
    let(:google_response) { 'bad response' }

    it 'does not proceed' do
      BestBetDocument.create(url: 'library.princeton.edu')
      expect { described_class.new.run }.not_to(change(BestBetDocument, :count))
    end
  end
end
