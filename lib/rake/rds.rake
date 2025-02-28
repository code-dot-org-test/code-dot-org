require 'cdo/aws/rds'
require lib_dir 'cdo/data/logging/rake_task_event_logger'
include TimedTaskWithLogging

namespace :rds do
  # Provide all 3 arguments
  # bundle exec rake rds:clone_cluster SOURCE_CLUSTER_ID=my-favorite-cluster CLONE_CLUSTER_ID=my-second-fav INSTANCE_ID=db.r4.4xlarge
  # Use default 'db.r4.large' instance type
  # bundle exec rake rds:clone_cluster SOURCE_CLUSTER_ID=my-favorite-cluster CLONE_CLUSTER_ID=my-second-fav
  # Use default clone id (suffix source cluster id with '-clone')
  # bundle exec rake rds:clone_cluster SOURCE_CLUSTER_ID=my-favorite-cluster
  desc 'Clone SOURCE_CLUSTER_ID to optional CLONE_CLUSTER_ID with optional INSTANCE_TYPE.'
  timed_task_with_logging :clone_cluster do
    options = {
      source_cluster_id: ENV['SOURCE_CLUSTER_ID'],
      clone_cluster_id: ENV['CLONE_CLUSTER_ID'],
      instance_type: ENV['INSTANCE_TYPE']
    }
    Cdo::RDS.clone_cluster(options.compact)
  end

  desc 'Delete CLUSTER_ID'
  timed_task_with_logging :delete_cluster do
    Cdo::RDS.delete_cluster(ENV['CLUSTER_ID'])
  end
end
