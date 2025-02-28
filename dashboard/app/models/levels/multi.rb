# == Schema Information
#
# Table name: levels
#
#  id                    :integer          not null, primary key
#  game_id               :integer
#  name                  :string(255)      not null
#  created_at            :datetime
#  updated_at            :datetime
#  level_num             :string(255)
#  ideal_level_source_id :bigint           unsigned
#  user_id               :integer
#  properties            :text(4294967295)
#  type                  :string(255)
#  md5                   :string(255)
#  published             :boolean          default(FALSE), not null
#  notes                 :text(65535)
#  audit_log             :text(65535)
#
# Indexes
#
#  index_levels_on_game_id    (game_id)
#  index_levels_on_level_num  (level_num)
#  index_levels_on_name       (name)
#

require "csv"

class Multi < Match
  def dsl_default
    <<~RUBY
      name '#{DEFAULT_LEVEL_NAME}'
      title 'title'
      description 'description here'
      question 'Question'
      wrong 'wrong answer'
      right 'right answer'
      allow_multiple_attempts false
    RUBY
  end

  # Return a string containing the correct indexes.  e.g. "3" or "0,1"
  def correct_answer_indexes
    # We use variable name _index so that the linter ignores the fact that it's not explicitly used.
    properties["answers"].each_with_index.select {|a, _index| a["correct"] == true}.map(&:last).join(",")
  end

  # Return an array containing the correct indexes.  e.g. [3] or [0,1]
  def correct_answer_indexes_array
    # We use variable name _index so that the linter ignores the fact that it's not explicitly used.
    properties["answers"].each_with_index.select {|a, _index| a["correct"] == true}.map(&:last)
  end

  # Converts a value (e.g. 0 or 1) to its displayed letter (e.g. "A" or "B")
  def self.value_to_letter(value)
    ("A".ord + value).chr
  end

  def get_question_text
    # Question text is stored in properties as "questions" or "markdown"
    question_text = ''
    unless properties['questions'].nil?
      question_text = properties['questions'][0]['text']
    end
    unless properties['markdown'].nil?
      question_text = properties['markdown']
    end
    return question_text
  end

  def summarize_for_lesson_show(can_view_teacher_markdown)
    localized_questions = localized_property(:questions)
    question_text = localized_questions.any? ? localized_questions[0]['text'] : nil
    super.merge(
      {
        questionText: question_text
      }
    )
  end
end
