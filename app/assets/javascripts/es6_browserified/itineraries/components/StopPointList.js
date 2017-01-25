var React = require('react')
var PropTypes = require('react').PropTypes
var StopPoint = require('./StopPoint')

const StopPointList = ({ stopPoints, onDeleteClick, onMoveUpClick, onMoveDownClick, onChange, onSelectChange, onToggleMap, onSelectMarker, onUnselectMarker }) => {
  return (
    <div className='list-group'>
      {stopPoints.map((stopPoint, index) =>
        <StopPoint
          key={'item-' + index}
          onDeleteClick={() => onDeleteClick(index)}
          onMoveUpClick={() => {
            onMoveUpClick(index)
          }}
          onMoveDownClick={() => onMoveDownClick(index)}
          onChange={ onChange }
          onSelectChange={ (e) => onSelectChange(e, index) }
          onToggleMap={() => onToggleMap(index)}
          onSelectMarker={onSelectMarker}
          onUnselectMarker={onUnselectMarker}
          first={ index === 0 }
          last={ index === (stopPoints.length - 1) }
          index={ index }
          value={ stopPoint }
        />
      )}
    </div>
  )
}

StopPointList.propTypes = {
  stopPoints: PropTypes.array.isRequired,
  onDeleteClick: PropTypes.func.isRequired,
  onMoveUpClick: PropTypes.func.isRequired,
  onMoveDownClick: PropTypes.func.isRequired,
  onSelectChange: PropTypes.func.isRequired,
  onSelectMarker: PropTypes.func.isRequired,
  onUnselectMarker : PropTypes.func.isRequired
}

module.exports = StopPointList
