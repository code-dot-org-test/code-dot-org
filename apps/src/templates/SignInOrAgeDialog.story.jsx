import React from 'react';
import {UnconnectedSignInOrAgeDialog as SignInOrAgeDialog} from './SignInOrAgeDialog';

export default {
  title: 'SignInOrAgeDialog',
  component: SignInOrAgeDialog,
};

const Template = args => (
  <SignInOrAgeDialog signedIn={false} age13Required={true} />
);

export const BasicExample = Template.bind({});
