import React, { Component } from 'react'
import PropTypes from 'prop-types'
import actions from '../actions'

export default class SaveVehicleJourneys extends Component{
  constructor(props){
    super(props)
  }

  render() {
    if (this.props.filters.policy['vehicle_journeys.update'] == false) {
      return false
    }else{
      return (
        <div className='row mt-md'>
          <div className='col-lg-12 text-right'>
            <form className='vehicle_journeys formSubmitr ml-xs' onSubmit={e => {e.preventDefault()}}>
              <div className="btn-group sticky-actions">
                <button
                  className={'btn btn-default' + (this.props.status.fetchSuccess ? '' : ' disabled')}
                  type='button'
                  onClick={e => {
                    e.preventDefault()
                    this.props.editMode ? this.props.onSubmitVehicleJourneys(this.props.dispatch, this.props.vehicleJourneys) : this.props.onEnterEditMode()
                  }}
                >
                  {this.props.editMode ? "Valider" : "Editer"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )
    }
  }
}

SaveVehicleJourneys.propTypes = {
  vehicleJourneys: PropTypes.array.isRequired,
  page: PropTypes.number.isRequired,
  status: PropTypes.object.isRequired,
  filters: PropTypes.object.isRequired,
  onEnterEditMode: PropTypes.func.isRequired,
  onExitEditMode: PropTypes.func.isRequired,
  onSubmitVehicleJourneys: PropTypes.func.isRequired
}
