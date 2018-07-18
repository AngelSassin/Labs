angular.module('temperature', [])
.controller('MainCtrl', [
  '$scope','$http',
  function($scope,$http){
    $scope.profile = [];
    $scope.current = [];
    $scope.temperatures = [];
    $scope.violations = [];

    $scope.eci = "g8kHejYxeQWcmPyfhq7ma";

    var bURL = 'http://localhost:8080/sky/event/'+$scope.eci+'/eid/sensor/profile_updated';
    $scope.updateProfile = function() {
      var pURL = bURL + "?name=" + $scope.name + "&location=" + $scope.location + "&threshold=" + $scope.threshold + "&number=" + $scope.number;
      return $http.post(pURL).success(function(data){
        $scope.name='';
        $scope.location='';
        $scope.threshold='';
        $scope.number='';
        $scope.getProfile();
      });
    };

    var iURL = 'http://localhost:8080/sky/event/'+$scope.eci+'/eid/timing/finished';
    $scope.finished = function(number) {
      var pURL = iURL + "?number=" + number;
      return $http.post(pURL).success(function(data){
        $scope.getAll();
      });
    };

    var proURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/sensor_profile/getProfile';
    $scope.getProfile = function() {
      return $http.get(proURL).success(function(data){
        angular.copy(data, $scope.profile);
      });
    };

    var cURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/current';
    $scope.getCurrent = function() {
      return $http.get(cURL).success(function(data){
        angular.copy(data, $scope.current);
      });
    };

    var gURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/temperatures';
    $scope.getAll = function() {
      return $http.get(gURL).success(function(data){
        angular.copy(data, $scope.temperatures);
      });
    };

    var vURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/threshold_violations';
    $scope.getViolations = function() {
      return $http.get(vURL).success(function(data){
        angular.copy(data, $scope.violations);
      });
    };

    $scope.getProfile();
    $scope.getCurrent();
    $scope.getAll();
    $scope.getViolations();
  }
]);