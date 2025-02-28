import React from 'react';
import {mount} from 'enzyme';
import {expect} from '../../../util/reconfiguredChai';
import i18n from '@cdo/locale';
import CurriculumQuickAssign from '@cdo/apps/templates/sectionsRefresh/CurriculumQuickAssign';

describe('CurriculumQuickAssign', () => {
  it('renders headers and the top row of buttons', () => {
    const wrapper = mount(
      <CurriculumQuickAssign updateSection={() => {}} sectionCourse={{}} />
    );

    expect(wrapper.find('h3').length).to.equal(1);
    expect(wrapper.find('p').length).to.equal(1);
    // We haven't specified participantType = student, so all 5 buttons appear
    expect(wrapper.find('Button').length).to.equal(5);
    expect(wrapper.find('Button').at(0).props().text).to.equal(
      i18n.courseBlocksGradeBandsElementary()
    );
    expect(
      wrapper.find('Button[id="uitest-high-button"]').props().text
    ).to.equal(i18n.courseBlocksGradeBandsHigh());
    expect(wrapper.find('input').length).to.equal(1);
  });

  it('updates caret direction when clicked', () => {
    const wrapper = mount(
      <CurriculumQuickAssign updateSection={() => {}} sectionCourse={{}} />
    );

    expect(wrapper.find('Button').at(0).props().icon).to.equal('caret-right');
    wrapper
      .find('Button')
      .at(0)
      .simulate('click', {preventDefault: () => {}});
    expect(wrapper.find('Button').at(0).props().icon).to.equal('caret-down');
  });

  it('opens and closes version dropdowns with table open and collapse', () => {
    const wrapper = mount(
      <CurriculumQuickAssign updateSection={() => {}} sectionCourse={{}} />
    );
    expect(wrapper.find('VersionUnitDropdowns')).to.have.lengthOf(0);
    wrapper
      .find('Button')
      .at(0)
      .simulate('click', {preventDefault: () => {}});
    expect(wrapper.find('VersionUnitDropdowns')).to.have.lengthOf(1);
    wrapper
      .find('Button')
      .at(0)
      .simulate('click', {preventDefault: () => {}});
    expect(wrapper.find('VersionUnitDropdowns')).to.have.lengthOf(0);
  });

  it('clears decide later when marketing audience selected', () => {
    const wrapper = mount(
      <CurriculumQuickAssign updateSection={() => {}} sectionCourse={{}} />
    );

    expect(wrapper.find('input').props().checked).to.equal(false);
    wrapper.find('input').simulate('change');
    expect(wrapper.find('input').props().checked).to.equal(true);

    // Now, click on elementary school button and verify checkbox is deselected
    wrapper.find('Button').at(0).simulate('click');
    expect(wrapper.find('input').props().checked).to.equal(false);
  });
});
