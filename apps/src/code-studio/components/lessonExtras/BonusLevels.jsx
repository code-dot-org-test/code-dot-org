import FontAwesome from '@cdo/apps/templates/FontAwesome';
import PropTypes from 'prop-types';
import Radium from 'radium'; // eslint-disable-line no-restricted-imports
import React from 'react';
import color from '../../../util/color';
import i18n from '@cdo/locale';
import {lessonOfBonusLevels} from './shapes';
import SublevelCard from '../SublevelCard';

const CARD_AREA_SIZE = 900;
const RadiumFontAwesome = Radium(FontAwesome);

class BonusLevels extends React.Component {
  static propTypes = {
    bonusLevels: PropTypes.arrayOf(PropTypes.shape(lessonOfBonusLevels)),
    sectionId: PropTypes.number,
    userId: PropTypes.number,
  };

  constructor(props) {
    super(props);
    this.state = {
      lessonIndex: props.bonusLevels.length - 1,
    };
  }

  nextLesson = () => {
    if (!this.isRightArrowDisabled()) {
      this.setState({lessonIndex: this.state.lessonIndex + 1});
    }
  };

  previousLesson = () => {
    if (!this.isLeftArrowDisabled()) {
      this.setState({lessonIndex: this.state.lessonIndex - 1});
    }
  };

  isLeftArrowDisabled = () => {
    return this.state.lessonIndex === 0;
  };

  isRightArrowDisabled = () => {
    return this.state.lessonIndex === this.props.bonusLevels.length - 1;
  };

  render() {
    const currLessonNum =
      this.props.bonusLevels[this.state.lessonIndex].lessonNumber;

    const previousNumLessons = this.props.bonusLevels.filter(
      lesson => lesson.lessonNumber < currLessonNum
    ).length;
    const scrollAmount = -1 * previousNumLessons * CARD_AREA_SIZE;

    const leftDisabled = this.isLeftArrowDisabled();
    const rightDisabled = this.isRightArrowDisabled();

    return (
      <div>
        <h2 style={styles.lessonNumberHeading}>
          {i18n.extrasStageNChallenges({
            lessonNumber: currLessonNum,
          })}
        </h2>
        <div style={styles.scroller}>
          <RadiumFontAwesome
            icon="caret-left"
            onClick={this.previousLesson}
            style={[styles.arrow, leftDisabled && styles.arrowDisabled]}
          />
          <div
            style={{
              ...styles.challenges,
              width: CARD_AREA_SIZE,
            }}
          >
            {this.props.bonusLevels.map(lesson => (
              <div
                key={lesson.lessonNumber}
                style={{
                  ...styles.challengeRow,
                  left: scrollAmount,
                  width: CARD_AREA_SIZE,
                }}
              >
                <div style={styles.cards}>
                  {lesson.levels.map(level => (
                    <SublevelCard
                      isLessonExtra={true}
                      sublevel={level}
                      key={level.id}
                      sectionId={this.props.sectionId}
                      userId={this.props.userId}
                    />
                  ))}
                </div>
              </div>
            ))}
          </div>
          <RadiumFontAwesome
            icon="caret-right"
            onClick={this.nextLesson}
            style={[styles.arrow, rightDisabled && styles.arrowDisabled]}
          />
        </div>
      </div>
    );
  }
}

const styles = {
  challengeRow: {
    clear: 'both',
    overflow: 'hidden',
    display: 'inline-block',
    position: 'relative',
    whiteSpace: 'normal',
    transition: 'left 0.25s ease-out',
    padding: '10px 0',
    verticalAlign: 'top',
  },
  challenges: {
    display: 'inline-block',
    overflowX: 'hidden',
    whiteSpace: 'nowrap',
    transition: 'width 0.1s ease-out',
    verticalAlign: 'top',
  },
  lessonNumberHeading: {
    backgroundColor: color.purple,
    width: '100%',
    textAlign: 'center',
    color: color.white,
    fontSize: 20,
    lineHeight: '35px',
    fontFamily: '"Gotham 4r"',
    margin: 0,
  },
  arrow: {
    fontSize: 40,
    cursor: 'pointer',
    verticalAlign: -30,
    margin: 10,
  },
  arrowDisabled: {
    color: color.lighter_gray,
    cursor: 'default',
  },
  cards: {
    display: 'flex',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    backgroundColor: color.white,
  },
  scroller: {
    backgroundColor: color.white,
    width: '100%',
    display: 'flex',
    flexDirection: 'row',
    alignItems: 'center',
  },
};

export default Radium(BonusLevels);
