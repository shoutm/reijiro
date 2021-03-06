class Clip < ActiveRecord::Base
  belongs_to :word

  validates :word_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: (0..8).to_a }

  after_initialize :set_default_values

  INTERVAL = { # TODO: マスタ化する
    0 => 0.second,
    1 => 1.day,
    2 => 2.days,
    3 => 4.days,
    4 => 1.week,
    5 => 2.weeks,
    6 => 1.month,
    7 => 2.months,
    8 => 4.months
  }

  scope :display, -> { order("clips.updated_at DESC") }
  scope :done, -> { where(status: 8) } # I'm done with the word!
  scope :undone, -> { where.not(status: 8) } # Still working on it!
  scope :level, -> (level) { joins(:word).where(words: { level: level }) }
  scope :overdue, -> (status) { where(status: status).where('updated_at < ?', Time.now - INTERVAL[status]) }

  def set_default_values
    self.status ||= 0
  end

  def update_with_checking_word(clip_params)
    self.word.checks.build(oldstat: self.status, newstat: clip_params[:status])
    self.update_attributes(clip_params)
  end

  class << self
    def overdue_count
      (0..7).inject(0){|acc, status| acc += Clip.overdue(status).count}
    end

    def next_clip
      # TODO: create status table?
      clip = nil
      (0..7).each do |status|
        clip = Clip.overdue(status).first
        break if clip.present?
      end
      clip # TODO: nilを返す必要があるか？ロジック見直す
    end

    def next_list
      overdue_word_ids = (0..7).inject([]) do |ids, status|
        ids + Clip.overdue(status).pluck(:word_id)
      end
      Word.clipped.where(id: overdue_word_ids).merge(Clip.display.order(:status))
    end

    def stats
      # TODO: データ構造要検討
      stats = {}

      stats['0'] = {
        undone: Clip.level(0).count,
        done: Clip.level(0).done.count,
        total: Clip.level(0).count,
        remain: 0
      }

      # TODO: GROUP BYで1クエリにできる
      (1..12).each do |level|
        undone = Clip.level(level).undone.count
        done   = Clip.level(level).done.count + Level.where(level: level).known.count # TODO: already = done + known のようなロジックにできないか
        total  = Level.where(level: level).count
        remain = total - (undone + done)
        stats[level] = { undone: undone, done: done, total: total, remain: remain }  # TODO: l.to_sするかArrayにする
      end

      stats['total'] = { # TODO: 再度SQLを投げずにキャッシュしたのを使えないか
        undone: Clip.undone.count,
        done: Clip.done.count,
        ramin: Level.count - Clip.count,
        total: Level.count
      }

      stats
    end
  end
end
