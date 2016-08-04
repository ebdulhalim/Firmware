#!/bin/bash
#
# Starts tests from within the container
#
# License: according to LICENSE.md in the root directory of the PX4 Firmware repository
set -e

pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null

SRC_DIR=`realpath ${SCRIPTPATH}/..`

JOB_DIR=$SRC_DIR/..
BUILD=posix_sitl_default
# TODO
ROS_TEST_RESULT_DIR=/root/.ros/test_results/px4
ROS_LOG_DIR=/root/.ros/log
PX4_LOG_DIR=${SRC_DIR}/build_${BUILD}/src/firmware/posix/rootfs/fs/microsd/log
TEST_RESULT_TARGET_DIR=$JOB_DIR/test_results
# BAGS=/root/.ros
# CHARTS=/root/.ros/charts
# EXPORT_CHARTS=/sitl/testing/export_charts.py

# source ROS env
if [ -f /opt/ros/indigo/setup.bash ]
then
	source /opt/ros/indigo/setup.bash
elif [ -f /opt/ros/kinetic/setup.bash ]
then
	source /opt/ros/kinetic/setup.bash
else
	echo "could not find /opt/ros/{ros-distro}/setup.bash"
	exit 1
fi

# setup Gazebo env and update package path
export GAZEBO_RESOURCE_PATH=${GAZEBO_RESOURCE_PATH}:${SRC_DIR}/Tools/sitl_gazebo
export GAZEBO_MODEL_PATH=${GAZEBO_MODEL_PATH}:${SRC_DIR}/Tools/sitl_gazebo/models
export GAZEBO_PLUGIN_PATH=${BINARY_DIR}/sitl_gazebo:${GAZEBO_PLUGIN_PATH}
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${SRC_DIR}/Tools/sitl_gazebo/Build/msgs/
export ROS_PACKAGE_PATH=${ROS_PACKAGE_PATH}:${SRC_DIR}
export GAZEBO_MODEL_DATABASE_URI=""
export SITL_GAZEBO_PATH=$SRC_DIR/Tools/sitl_gazebo
source $SRC_DIR/integrationtests/setup_gazebo_ros.bash $SRC_DIR

echo "deleting previous test results ($TEST_RESULT_TARGET_DIR)"
if [ -d ${TEST_RESULT_TARGET_DIR} ]; then
	rm -r ${TEST_RESULT_TARGET_DIR}
fi

cd /tmp
mkdir -p /tmp/catkin/src
cd /tmp/catkin/src
ln -s $SRC_DIR px4
cd /tmp/catkin
catkin_make

# don't exit on error anymore from here on (because single tests or exports might fail)
set +e
echo "=====> run tests"
rostest px4 mavros_posix_tests_iris.launch
rostest px4 mavros_posix_tests_standard_vtol.launch
TEST_RESULT=$?
echo "<====="

# TODO
echo "=====> process test results"
# cd $BAGS
# for bag in `ls *.bag`
# do
# 	echo "processing bag: $bag"
# 	python $EXPORT_CHARTS $CHARTS $bag
# done

echo "copy build test results to job directory"
mkdir -p ${TEST_RESULT_TARGET_DIR}
cp -r $ROS_TEST_RESULT_DIR/* ${TEST_RESULT_TARGET_DIR}
cp -r $ROS_LOG_DIR/* ${TEST_RESULT_TARGET_DIR}
cp -r $PX4_LOG_DIR/* ${TEST_RESULT_TARGET_DIR}
# cp $BAGS/*.bag ${TEST_RESULT_TARGET_DIR}/
# cp -r $CHARTS ${TEST_RESULT_TARGET_DIR}/
echo "<====="

# need to return error if tests failed, else Jenkins won't notice the failure
exit $TEST_RESULT
