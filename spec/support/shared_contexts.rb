shared_context 'just created 100 clips' do
  background do
    create_list(:clip, 100)
    Word.stub(:lookup_thesaurus) { "none" }
    Word.stub(:search) do |query|
      c = create :clip
      c.word.update_column(:entry, query)
      c.word
    end
  end
end
