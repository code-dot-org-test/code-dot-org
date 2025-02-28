import React from 'react';
import {action} from '@storybook/addon-actions';
import {UnconnectedProgressDetailToggle as ProgressDetailToggle} from './ProgressDetailToggle';
import {reduxStore} from '@cdo/storybook/decorators';
import {Provider} from 'react-redux';

export default {
  title: 'ProgressDetailToggle',
  component: ProgressDetailToggle,
};

const Template = args => (
  <Provider store={reduxStore()}>
    <ProgressDetailToggle
      setIsSummaryView={action('setIsSummaryView')}
      isPlc={false}
      {...args}
    />
  </Provider>
);

export const YesSummaryNoGroups = Template.bind({});
YesSummaryNoGroups.args = {
  isSummaryView: true,
  hasGroups: false,
};

export const NoSummaryNoGroups = Template.bind({});
NoSummaryNoGroups.args = {
  isSummaryView: false,
  hasGroups: false,
};

export const YesSummaryYesGroups = Template.bind({});
YesSummaryYesGroups.args = {
  isSummaryView: true,
  hasGroups: true,
};

export const NoSummaryYesGroups = Template.bind({});
NoSummaryYesGroups.args = {
  isSummaryView: false,
  hasGroups: true,
};
