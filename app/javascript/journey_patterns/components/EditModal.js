import _ from 'lodash'
import React, { Component } from 'react'
import PropTypes from 'prop-types'
import actions from '../actions'
import CustomFieldsInputs from '../../helpers/CustomFieldsInputs'
import ShapeSelector from './ShapeSelector'
import ShapeMap from './ShapeMap'

export default class EditModal extends Component {
  constructor(props) {
    super(props)
    this.updateValue = this.updateValue.bind(this)
  }

  handleSubmit() {
    if(actions.validateFields(this.refs) == true) {
      this.props.saveModal(this.props.modal.modalProps.index,
        _.assign({}, this.refs, {
          custom_fields: this.custom_fields,
          shape: this.props.modal.modalProps.journeyPattern.shape ? {id: this.props.modal.modalProps.journeyPattern.shape.id, name: this.props.modal.modalProps.journeyPattern.shape.name, uuid: this.props.modal.modalProps.journeyPattern.shape.uuid } : undefined
        })
      )
      $('#JourneyPatternModal').modal('hide')
    }
  }

  updateValue(attribute, e) {
    actions.resetValidation(e.currentTarget)
    this.props.modal.modalProps.journeyPattern[attribute] = e.target.value
    this.forceUpdate()
  }

  renderModalTitle() {
    if (this.props.editMode) {
      return (
        <h4 className='modal-title'>
          {I18n.t('journey_patterns.actions.edit')}
          {this.props.modal.type == 'edit' && <em> "{this.props.modal.modalProps.journeyPattern.name}"</em>}
        </h4>
      )
    } else {
      return <h4 className='modal-title'> {I18n.t('journey_patterns.show.informations')} </h4>
    }
  }

  render() {
    if(this.props.modal.modalProps.journeyPattern){
      this.custom_fields = _.assign({}, this.props.modal.modalProps.journeyPattern.custom_fields)
    }
    return (
      <div className={ 'modal fade ' + ((this.props.modal.type == 'edit') ? 'in' : '') } id='JourneyPatternModal'>
        <div className='modal-container'>
          <div className='modal-dialog'>
            <div className='modal-content'>
              <div className='modal-header'>
                {this.renderModalTitle()}
                <span type="button" className="close modal-close" data-dismiss="modal">&times;</span>
              </div>
              {(this.props.modal.type == 'edit') && (
                <form>
                  <div className='modal-body'>
                    <div className='row'>
                      <div className='col-xs-6'>
                        <div className='form-group'>
                          <label className='control-label is-required'>{I18n.attribute_name('journey_pattern', 'name')}</label>
                          <input
                            type='text'
                            ref='name'
                            className='form-control'
                            disabled={!this.props.editMode}
                            id={this.props.modal.modalProps.index}
                            value={this.props.modal.modalProps.journeyPattern.name}
                            onChange={(e) => this.updateValue('name', e)}
                            required
                            />
                        </div>
                      </div>
                    </div>
                    <div className='row'>
                      <div className='col-xs-6'>
                        <div className='form-group'>
                          <label className='control-label is-required'>{I18n.attribute_name('journey_pattern', 'published_name')}</label>
                          <input
                            type='text'
                            ref='published_name'
                            className='form-control'
                            disabled={!this.props.editMode}
                            id={this.props.modal.modalProps.index}
                            value={this.props.modal.modalProps.journeyPattern.published_name}
                            onChange={(e) => this.updateValue('published_name', e)}
                            required
                            />
                        </div>
                      </div>
                      <div className='col-xs-6'>
                        <div className='form-group'>
                          <label className='control-label'>{I18n.attribute_name('journey_pattern', 'registration_number')}</label>
                          <input
                            type='text'
                            ref='registration_number'
                            className='form-control'
                            disabled={!this.props.editMode}
                            id={this.props.modal.modalProps.index}
                            value={this.props.modal.modalProps.journeyPattern.registration_number}
                            onChange={(e) => this.updateValue('registration_number', e)}
                            />
                        </div>
                      </div>
                    </div>
                    <div className='row'>
                      <CustomFieldsInputs
                        values={this.props.modal.modalProps.journeyPattern.custom_fields}
                        onUpdate={(code, value) => this.custom_fields[code]["value"] = value}
                        disabled={!this.props.editMode}
                      />
                    </div>
                    <div className='row'>
                      <div className='col-xs-12'>
                        <div className='form-group'>
                          <label className='control-label'>{I18n.attribute_name('journey_pattern', 'shape')}</label>
                          <ShapeSelector
                            shape = {this.props.modal.modalProps.journeyPattern.shape}
                            onSelectShape = {(e) => this.props.onSelectShape(e)}
                            onUnselectShape = {() => this.props.onUnselectShape()}
                            disabled={!this.props.editMode}
                          />
                        </div>
                      </div>
                    </div>
                    <div className='row'>
                      <div className='col-xs-12 shape-map'>
                        <ShapeMap shapeId={_.get(this.props.modal.modalProps, 'journeyPattern.shape.id')}/>
                      </div>
                    </div>
                    <div>
                      <label className='control-label'>{I18n.attribute_name('journey_pattern', 'checksum')}</label>
                        <input
                        type='text'
                        ref='checksum'
                        className='form-control'
                        readOnly={true}
                        value={this.props.modal.modalProps.journeyPattern.checksum}
                        />
                    </div>
                  </div>
                  {
                    this.props.editMode &&
                    <div className='modal-footer'>
                      <button
                        className='btn btn-link'
                        data-dismiss='modal'
                        type='button'
                        onClick={this.props.onModalClose}
                      >
                        {I18n.t('cancel')}
                      </button>
                      <button
                        className='btn btn-primary'
                        type='button'
                        onClick={this.handleSubmit.bind(this)}
                      >
                        {I18n.t('actions.submit')}
                      </button>
                    </div>
                  }
                </form>
              )}
            </div>
          </div>
        </div>
      </div>
    )
  }
}

EditModal.propTypes = {
  index: PropTypes.number,
  modal: PropTypes.object,
  onModalClose: PropTypes.func.isRequired,
  saveModal: PropTypes.func.isRequired
}
