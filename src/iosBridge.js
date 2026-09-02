import * as Cesium from 'cesium';

/**
 * Native iOS bridge for God's Eye View.
 *
 * Keeps Swift isolated from internal implementation details
 * of individual data layers.
 */

function postToNative(type, payload = {}) {
  if (!window.GEVNative?.postMessage) return;

  window.GEVNative.postMessage(type, payload);
}


function serializeAircraft(info) {
  if (!info) return null;

  const altitudeM = Number.isFinite(info.altitudeM)
    ? info.altitudeM
    : null;

  const velocityMps = Number.isFinite(info.velocityMps)
    ? info.velocityMps
    : null;

  const track = Number.isFinite(info.track)
    ? info.track
    : null;

  return {
    icao24: info.icao24 || '',
    callsign: info.callsign || null,
    registration: info.registration || null,
    airline: info.airline || null,

    typeName:
      info.typeName
      || info.typeCode
      || null,

    latitude:
      Number.isFinite(info.latitude)
        ? info.latitude
        : null,

    longitude:
      Number.isFinite(info.longitude)
        ? info.longitude
        : null,

    altitudeM,

    altitudeFeet:
      altitudeM !== null
        ? Math.round(
            altitudeM * 3.28084
          )
        : null,

    velocityMps,

    speedKmh:
      velocityMps !== null
        ? Math.round(
            velocityMps * 3.6
          )
        : null,

    track,

    heading:
      track !== null
        ? Math.round(track)
        : null,

    onGround:
      info.onGround === true,

    stale:
      info.stale === true,

    origin:
      info.origin || null,

    destination:
      info.destination || null,
  };
}


export function installIOSBridge({
  dataManager,
  flightsLayer,
}) {
  if (typeof window === 'undefined') {
    return null;
  }

  if (window.GEViOS) {
    return window.GEViOS;
  }


  let trackedUpdateTimer = null;


  const stopTrackedUpdates = () => {
    if (trackedUpdateTimer !== null) {
      window.clearInterval(
        trackedUpdateTimer
      );

      trackedUpdateTimer = null;
    }
  };


  const publishTrackedAircraft = (
    type = 'aircraft-updated'
  ) => {
    const info =
      flightsLayer
        ?.getTrackedInfo
        ?.();

    if (!info) {
      return false;
    }


    const aircraft =
      serializeAircraft(
        info
      );

    if (!aircraft) {
      return false;
    }


    postToNative(
      type,
      aircraft
    );

    return true;
  };


  const startTrackedUpdates = () => {
    stopTrackedUpdates();


    trackedUpdateTimer =
      window.setInterval(
        () => {
          publishTrackedAircraft(
            'aircraft-updated'
          );
        },
        1000
      );
  };


  const getNearbyFlights = (
    latitude,
    longitude,
    radiusKm = 100,
    maxCount = 20
  ) => {
    if (!flightsLayer?.getNearby) {
      return [];
    }


    const lat =
      Number(latitude);

    const lon =
      Number(longitude);

    const radius =
      Number(radiusKm);

    const limit =
      Number(maxCount);


    if (
      !Number.isFinite(lat)
      || !Number.isFinite(lon)
    ) {
      return [];
    }


    const center =
      Cesium.Cartesian3
        .fromDegrees(
          lon,
          lat,
          0
        );


    const radiusMeters =
      Number.isFinite(radius)
      && radius > 0
        ? radius * 1000
        : 100000;


    const resultLimit =
      Number.isFinite(limit)
      && limit > 0
        ? Math.floor(limit)
        : 20;


    const nearby =
      flightsLayer.getNearby(
        center,
        radiusMeters,
        resultLimit
      );


    return nearby.map(
      (item) => {

        const altitudeM =
          Number.isFinite(
            item.altitudeM
          )
            ? item.altitudeM
            : null;


        const velocityMps =
          Number.isFinite(
            item.velocityMps
          )
            ? item.velocityMps
            : null;


        const track =
          Number.isFinite(
            item.track
          )
            ? item.track
            : null;


        return {
          icao24:
            item.icao24 || '',

          callsign:
            item.callsign || null,

          onGround:
            item.onGround === true,

          distanceKm:
            Number.isFinite(
              item.distance
            )
              ? Math.round(
                  (
                    item.distance
                    / 1000
                  ) * 10
                ) / 10
              : 0,

          altitudeFeet:
            altitudeM !== null
              ? Math.round(
                  altitudeM
                  * 3.28084
                )
              : null,

          speedKmh:
            velocityMps !== null
              ? Math.round(
                  velocityMps
                  * 3.6
                )
              : null,

          heading:
            track !== null
              ? Math.round(
                  track
                )
              : null,

          aircraftClass:
            item.aircraftClass
            || null,
        };
      }
    );
  };


  const onAircraftSelected = (
    event
  ) => {
    if (
      event.detail?.layerId
      !== 'flights'
    ) {
      return;
    }


    publishTrackedAircraft(
      'aircraft-selected'
    );


    startTrackedUpdates();
  };


  const onAircraftCleared = (
    event
  ) => {
    if (
      event.detail?.layerId
      !== 'flights'
    ) {
      return;
    }


    stopTrackedUpdates();


    postToNative(
      'aircraft-cleared',
      {
        id:
          event.detail?.id
          || null,
      }
    );
  };


  window.addEventListener(
    'gev:awareness-subject-selected',
    onAircraftSelected
  );


  window.addEventListener(
    'gev:awareness-subject-cleared',
    onAircraftCleared
  );


  const api = {

    async setLayer(
      id,
      enabled
    ) {
      if (!dataManager) {
        return false;
      }


      try {

        const result =
          await dataManager
            .setEnabled(
              id,
              Boolean(enabled),
              {
                origin:
                  'user',
              }
            );


        const actualEnabled =
          dataManager
            .isEnabled(
              id
            );


        postToNative(
          'layer-changed',
          {
            id,

            enabled:
              actualEnabled,
          }
        );


        return result !== false;

      } catch (error) {

        postToNative(
          'layer-error',
          {
            id,

            message:
              error?.message
              || String(error),
          }
        );


        return false;
      }
    },


    getNearbyFlights(
      latitude,
      longitude,
      radiusKm = 100,
      maxCount = 20
    ) {

      return getNearbyFlights(
        latitude,
        longitude,
        radiusKm,
        maxCount
      );
    },


    publishNearbyFlights(
      latitude,
      longitude,
      radiusKm = 100,
      maxCount = 20
    ) {

      const items =
        getNearbyFlights(
          latitude,
          longitude,
          radiusKm,
          maxCount
        );


      postToNative(
        'nearby-flights',
        {
          items,
        }
      );


      return items.length;
    },


    trackAircraft(
      icao24
    ) {
      if (
        !flightsLayer
          ?.trackById
      ) {
        return false;
      }


      const id =
        String(
          icao24 || ''
        ).trim();


      if (!id) {
        return false;
      }


      const result =
        flightsLayer
          .trackById(
            id,
            {
              origin:
                'user',
            }
          );


      if (!result) {

        postToNative(
          'aircraft-track-error',
          {
            icao24:
              id,
          }
        );
      }


      return result;
    },


    getSelectedAircraft() {

      const info =
        flightsLayer
          ?.getTrackedInfo
          ?.();


      return serializeAircraft(
        info
      );
    },


    stopTracking() {

      if (
        !flightsLayer
          ?.stopTracking
      ) {
        return false;
      }


      flightsLayer
        .stopTracking(
          {
            origin:
              'user',
          }
        );


      return true;
    },
  };


  window.GEViOS =
    api;


  postToNative(
    'ios-bridge-ready',
    {}
  );


  return api;
}