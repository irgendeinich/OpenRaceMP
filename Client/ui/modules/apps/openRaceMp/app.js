var app = angular.module('beamng.apps');
app.directive('openRaceMp', [function () {
    return {
        templateUrl: '/ui/modules/apps/openRaceMp/app.html',
        replace: true,
        restrict: 'EA',
        scope: true,
        controllerAs: 'ctrl'
    }
}]);
app.controller("OpenRaceMp", ['$scope', function ($scope) {
    $scope.currentState = 'setup'
    $scope.setupEnabled = true
    $scope.currentlyWaiting = false
    $scope.currentLap = 0
    $scope.lapCount = 0
    $scope.raceTimeLap = null
    $scope.raceTimeTotal = null

    $scope.previousWaypoint = null
    $scope.previousWaypointTimings = [];

    $scope.nextWaypoint = '1-1'
    $scope.nextWaypointTimings = [];

    var newLap = false;
    var offset = 0;

    var timings = {};

    $scope.tracks = [];

    bngApi.engineLua('openRaceMp.getTrackList()', function (data) {
        $scope.$evalAsync(function () {
            $scope.tracks = data
        })
    });

    $scope.$on('openRaceMp.setSetupEnabled', function (event, data) {
        $scope.setupEnabled = data
    });

    $scope.loadTrack = function (path) {
        bngApi.engineLua(`openRaceMp.remoteTriggerLoadTrack('${path}')`, function (data) {
        })
    };

    $scope.startRace = function () {
        bngApi.engineLua('openRaceMp.remoteTriggerStartRace()', function (data) {
        });
    };

    $scope.$on('openRaceMp.raceTime', function (event, data) {
        $scope.currentState = 'racing'
        if (newLap) {
            offset = data.reverseTime ? 0 : data.time
            newLap = false
        }
        $scope.$evalAsync(function () {
            $scope.raceTimeLap = (data.time - offset) * 1000
            $scope.raceTimeTotal = (data.time) * 1000
        })
    });

    $scope.$on('openRaceMp.raceLapChange', function (event, data) {
        if (data) {
            $scope.currentLap = data.current
            $scope.lapCount = data.count
        }
        if (data && data.current > 1) {
            newLap = true
        }
        if (data && data.current == 1) {
            offset = 0;
            $scope.raceTimeLap = null;
            $scope.raceTimeTotal = null;
        }
    })


    var sortTimings = function (times) {
        return times.sort((a, b) => a.time - b.time);
    }

    var updateTimings = function () {
        // Grab the timinigs for the currently shown waypoints.
        $scope.previousWaypointTimings = sortTimings(timings[$scope.previousWaypoint] || []);
        $scope.nextWaypointTimings = sortTimings(timings[$scope.nextWaypoint] || []);
    };

    $scope.$on('openRaceMp.raceWaypoint', function (event, data) {
        if (data.currentLap) {
            $scope.currentLap = data.currentLap
        }
        if (data.lapCount) {
            $scope.lapCount = data.lapCount
        }
        $scope.previousWaypoint = data.previousWaypoint
        $scope.nextWaypoint = data.nextWaypoint

        updateTimings();
    });

    $scope.$on('openRaceMp.raceStarting', function (event, data) {
        $scope.currentState = 'countdown'
    })

    $scope.$on('openRaceMp.raceEnd', function (event, data) {
        $scope.currentState = 'end'
    })

    $scope.$on('openRaceMp.timingsUpdated', function (event, data) {
        $scope.$evalAsync(function () {
            timings = data
            updateTimings();
        })
    });
}]);
