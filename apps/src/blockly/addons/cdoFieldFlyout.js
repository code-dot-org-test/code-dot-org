import GoogleBlockly from 'blockly/core';
import CdoBlockFlyout from './cdoBlockFlyout';

export default class CdoFieldFlyout extends GoogleBlockly.Field {
  /**
   * This is a customized class that extends Blockly's Field class.
   * This field depends on `CdoBlockFlyout`, which is used to create a flyout
   * of blocks. We colloquially refer to this as a block's "mini-toolbox".
   *
   * @param {string} value - The initial value of the field.
   * @param {Object} [opt_config] - A map of options used to configure the field.
   * @param {number} [opt_config.minWidth] - The minimum width of the field.
   * @param {number} [opt_config.maxWidth] - The maximum width of the field.
   */
  constructor(value, opt_config) {
    super(value);
    this.configure_(opt_config);
  }

  /**
   * Construct a FieldFlyout from a JSON arg object.
   *
   * @param {Object} options A JSON object with options.
   * @returns {CdoFieldFlyout} The new field instance.
   */
  static fromJson(options) {
    return new CdoFieldFlyout(options.flyoutKey, options);
  }

  static getFlyoutId(block) {
    return `flyout_${block.type}_${block.id}`;
  }

  EDITABLE = false;
  CURSOR = 'default';

  /**
   * Process the configuration map passed to the field.
   *
   * @param {Object} [config] - A map of options used to configure the field.
   * @param {number} [config.minWidth] - The minimum width of the field.
   * @param {number} [config.maxWidth] - The maximum width of the field.
   * @override
   */
  configure_(config) {
    if (config) {
      this.minWidth_ = config.minWidth;
      this.maxWidth_ = config.maxWidth;
    }
  }

  /**
   * Create the block UI for this field.
   * @override
   */
  initView() {
    this.workspace_ = this.getSourceBlock().workspace;
    this.flyout_ = new CdoBlockFlyout({
      ...Blockly.getMainWorkspace().options,
      disabledPatternId: this.workspace_.options.disabledPatternId,
      parentWorkspace: this.workspace_,
      RTL: this.workspace_.RTL,
      minWidth: this.minWidth_,
      maxWidth: this.maxWidth_,
    });
    this.flyout_.setSourceBlock_(this.getSourceBlock());
    this.fieldGroup_.appendChild(this.flyout_.createDom('g'));
  }

  /**
   * This is the Blockly hook to create an editor for the field.
   * @override
   */
  showEditor_() {
    this.setFlyoutVisible(!this.isFlyoutVisible());
  }

  /**
   * Returns the height and width of the field.
   *
   * This should *in general* be the only place render_ gets called from.
   *
   * @returns {Blockly.utils.Size} Height and width.
   * @override
   */
  getSize() {
    if (!this.isVisible()) {
      return new Blockly.utils.Size(0, 0);
    }
    // Normally, Blockly skips rendering fields unless we've notified the
    // rendering system that they've changed (this.isDirty_), but in this
    // case, we want to always re-render / resize the field so that it
    // matches the width of the block.
    this.render_();

    if (this.visible_ && this.size_.width === 0) {
      // If the field is not visible the width will be 0 as well, one of the
      // problems with the old system.
      this.render_();
    }

    return this.size_;
  }

  /**
   * Used by getSize() to move/resize any DOM elements, and get the new size.
   *
   * All rendering that has an effect on the size/shape of the block should be
   * done here, and should be triggered by getSize().
   * @override
   */
  render_() {
    this.showEditor_();
    const fieldGroupBBox = this.fieldGroup_.getBBox();
    if (this.flyout_.isVisible()) {
      this.size_ = new Blockly.utils.Size(
        this.flyout_.getWidth(),
        fieldGroupBBox.height
      );
    } else {
      this.size_ = new Blockly.utils.Size(
        fieldGroupBBox.width,
        fieldGroupBBox.height
      );
    }
  }

  /**
   * Show or hide the flyout, then re-render it.
   *
   * @param {boolean} isVisible Whether or not the flyout should be shown.
   */
  setFlyoutVisible(isVisible) {
    if (!this.flyout_.targetWorkspace) {
      this.flyout_.init(this.workspace_);
    }
    isVisible
      ? this.flyout_.show(CdoFieldFlyout.getFlyoutId(this.sourceBlock_))
      : this.flyout_.hide();
    this.forceRerender();
  }

  /**
   * Is this field's flyout visible?
   *
   * @returns True if visible.
   */
  isFlyoutVisible() {
    return this.flyout_.isVisible();
  }
}
