# frozen_string_literal: true

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "google/cloud/bigtable/version"
require "google/cloud/bigtable/errors"
require "google/cloud/bigtable/credentials"
require "google/cloud/bigtable/admin/v2/bigtable_instance_admin_client"
require "google/cloud/bigtable/admin/v2/bigtable_table_admin_client"
require "google/cloud/bigtable/v2/bigtable_client"

module Google
  module Cloud
    module Bigtable
      # @private
      # Represents the gRPC Bigtable service, including all the API methods.
      class Service
        # @private
        attr_accessor :project_id, :credentials, :host, :timeout, :client_config

        # @private
        # Creates a new Service instance.
        #
        # @param project_id [String] Project identifier
        # @param credentials [Google::Auth::Credentials, String, Hash, GRPC::Core::Channel, GRPC::Core::ChannelCredentials, Proc]
        #   Provides the means for authenticating requests made by the client. This parameter can
        #   be many types.
        #   A `Google::Auth::Credentials` uses a the properties of its represented keyfile for
        #   authenticating requests made by this client.
        #   A `String` will be treated as the path to the keyfile to be used for the construction of
        #   credentials for this client.
        #   A `Hash` will be treated as the contents of a keyfile to be used for the construction of
        #   credentials for this client.
        #   A `GRPC::Core::Channel` will be used to make calls through.
        #   A `GRPC::Core::ChannelCredentials` for the setting up the RPC client. The channel credentials
        #   should already be composed with a `GRPC::Core::CallCredentials` object.
        #   A `Proc` will be used as an updater_proc for the Grpc channel. The proc transforms the
        #   metadata for requests, generally, to give OAuth credentials.
        # @param timeout [Integer]
        #   The default timeout, in seconds, for calls made through this client.
        # @param client_config [Hash]
        #   A Hash for call options for each method.
        #   See Google::Gax#construct_settings for the structure of
        #   this data. Falls back to the default config if not specified
        #   or the specified config is missing data points.

        def initialize project_id, credentials, host: nil, timeout: nil,
                       client_config: nil
          @project_id = project_id
          @credentials = credentials
          @host = host
          @timeout = timeout
          @client_config = client_config || {}
        end

        def channel default_host
          require "grpc"
          GRPC::Core::Channel.new((host || default_host), nil, chan_creds)
        end

        def chan_creds
          return credentials if insecure?
          require "grpc"
          GRPC::Core::ChannelCredentials.new.compose \
            GRPC::Core::CallCredentials.new credentials.client.updater_proc
        end

        # Create or return existing instance of instance admin client.
        #
        # @return [Google::Cloud::Bigtable::Admin::V2::BigtableInstanceAdminClient]

        def instances
          @instances ||= begin
            instances_channel = channel(
              Admin::V2::BigtableInstanceAdminClient::SERVICE_ADDRESS
            )
            Admin::V2::BigtableInstanceAdminClient.new(
              credentials: instances_channel,
              timeout: timeout,
              client_config: client_config,
              lib_name: "gccl",
              lib_version: Google::Cloud::Bigtable::VERSION
            )
          end
        end

        # Create or return existing instance of table admin client.
        #
        # @return [Google::Cloud::Bigtable::Admin::V2::BigtableTableAdminClient]

        def tables
          @tables ||= begin
            tables_channel = channel(
              Admin::V2::BigtableTableAdminClient::SERVICE_ADDRESS
            )
            Admin::V2::BigtableTableAdminClient.new(
              credentials: tables_channel,
              timeout: timeout,
              client_config: client_config,
              lib_name: "gccl",
              lib_version: Google::Cloud::Bigtable::VERSION
            )
          end
        end

        # Create instance of data client.
        #
        # @return [Google::Cloud::Bigtable::V2::BigtableClient]

        def client
          @client ||= \
            V2::BigtableClient.new(
              credentials: channel(V2::BigtableClient::SERVICE_ADDRESS),
              timeout: timeout,
              client_config: client_config,
              lib_name: "gccl",
              lib_version: Google::Cloud::Bigtable::VERSION
            )
        end

        def insecure?
          credentials == :this_channel_is_insecure
        end

        # Create an instance within a project.
        #
        # @param instance_id [String]
        #   The ID to be used when referring to the new instance within its project.
        #   e.g., +myinstance+
        # @param instance [Google::Bigtable::Admin::V2::Instance | Hash]
        # @param clusters [Hash{String => Google::Bigtable::Admin::V2::Cluster | Hash}]
        #   The clusters to be created within the instance, mapped by desired
        #   cluster ID, e.g., just +mycluster+ rather than
        #   +projects/myproject/instances/myinstance/clusters/mycluster+.
        #   Fields marked +OutputOnly+ must be left blank.
        #   Currently exactly one cluster must be specified.
        #   A hash of the same form as `Google::Bigtable::Admin::V2::Cluster`
        #   can also be provided.
        # @return [Google::Gax::Operation]

        def create_instance \
            instance_id,
            instance,
            clusters
          execute do
            instances.create_instance(
              project_path,
              instance_id,
              instance,
              clusters
            )
          end
        end

        # Lists information about instances in a project.
        #
        # @param token [String]
        #   The value of +next_page_token+ returned by a previous call.
        # @return [Google::Bigtable::Admin::V2::ListInstancesResponse]

        def list_instances token: nil
          execute do
            instances.list_instances(
              project_path,
              page_token: token
            )
          end
        end

        # Gets information about an instance.
        #
        # @param instance_id [String]
        #   The unique ID of the requested instance.
        # @return [Google::Bigtable::Admin::V2::Instance]

        def get_instance instance_id
          execute do
            instances.get_instance(
              instance_path(instance_id)
            )
          end
        end

        # Partially updates an instance within a project.
        #
        # @param instance [Google::Bigtable::Admin::V2::Instance | Hash]
        #   The Instance which will (partially) replace the current value.
        #   A hash of the same form as `Google::Bigtable::Admin::V2::Instance`
        #   can also be provided.
        # @param update_mask [Google::Protobuf::FieldMask | Hash]
        #   The subset of Instance fields which should be replaced.
        #   Must be explicitly set.
        #   A hash of the same form as `Google::Protobuf::FieldMask`
        #   can also be provided.
        # @return [Google::Gax::Operation]

        def partial_update_instance instance, update_mask
          execute do
            instances.partial_update_instance(instance, update_mask)
          end
        end

        # Delete an instance from a project.
        #
        # @param instance_id [String]
        #   The unique Id of the instance to be deleted.

        def delete_instance instance_id
          execute do
            instances.delete_instance(
              instance_path(instance_id)
            )
          end
        end

        # Create a cluster within an instance.
        #
        # @param instance_id [String]
        #   The unique name of the instance in which to create the new cluster
        # @param cluster_id [String]
        #   The ID to be used when referring to the new cluster within its instance,
        #   e.g., just +mycluster+
        # @param cluster [Google::Bigtable::Admin::V2::Cluster | Hash]
        #   The cluster to be created.
        #   Fields marked +OutputOnly+ must be left blank.
        #   A hash of the same form as `Google::Bigtable::Admin::V2::Cluster`
        #   can also be provided.
        # @return [Google::Gax::Operation]

        def create_cluster instance_id, cluster_id, cluster
          unless cluster.location == ""
            cluster.location = location_path(cluster.location)
          end

          execute do
            instances.create_cluster(
              instance_path(instance_id),
              cluster_id,
              cluster
            )
          end
        end

        # Lists information about clusters in an instance.
        #
        # @param instance_id [String]
        #   The unique name of the instance for which a list of clusters is requested.
        # @param token [String]
        #   The value of +next_page_token+ returned by a previous call.
        # @return [Google::Bigtable::Admin::V2::ListClustersResponse]

        def list_clusters instance_id, token: nil
          execute do
            instances.list_clusters(
              instance_path(instance_id),
              page_token: token
            )
          end
        end

        # Gets information about a cluster.
        #
        # @param instance_id [String]
        #   The unique Id of the instance.
        # @param cluster_id [String]
        #   The unique Id of the requested cluster.
        # @return [Google::Bigtable::Admin::V2::Cluster]

        def get_cluster instance_id, cluster_id
          execute do
            instances.get_cluster(
              cluster_path(instance_id, cluster_id)
            )
          end
        end

        # Updates a cluster within an instance.
        #
        # @param instance_id [String]
        #   The unique Id of the instance.
        # @param cluster_id [String]
        #   The unique Id of the cluster.
        # @param location [String]
        #   The location where this cluster's nodes and storage reside. For best
        #   performance, clients should be located as close as possible to this
        #   cluster. Currently only zones are supported, so values should be of the
        #   form +projects/<project>/locations/<zone>+.
        # @param serve_nodes [Integer]
        #   The number of nodes allocated to this cluster. More nodes enable higher
        #   throughput and more consistent performance.
        # @return [Google::Gax::Operation]

        def update_cluster instance_id, cluster_id, location, serve_nodes
          execute do
            instances.update_cluster(
              cluster_path(instance_id, cluster_id),
              location,
              serve_nodes
            )
          end
        end

        # Deletes a cluster from an instance.
        #
        # @param instance_id [String]
        #   The unique Id of the instance in which cluster present.
        # @param cluster_id [String]
        #    The unique Id of the cluster to be deleted.

        def delete_cluster instance_id, cluster_id
          execute do
            instances.delete_cluster(
              cluster_path(instance_id, cluster_id)
            )
          end
        end

        # Creates a new table in the specified instance.
        # The table can be created with a full set of initial column families,
        # specified in the request.
        #
        # @param instance_id [String]
        #   The unique Id of the instance in which to create the table.
        # @param table_id [String]
        #   The name by which the new table should be referred to within the parent
        #   instance, e.g., +foobar+
        # @param table [Google::Bigtable::Admin::V2::Table | Hash]
        #   The Table to create.
        #   A hash of the same form as `Google::Bigtable::Admin::V2::Table`
        #   can also be provided.
        # @param initial_splits [Array<Google::Bigtable::Admin::V2::CreateTableRequest::Split | Hash>]
        #   The optional list of row keys that will be used to initially split the
        #   table into several tablets (tablets are similar to HBase regions).
        #   Given two split keys, +s1+ and +s2+, three tablets will be created,
        #   spanning the key ranges: +[, s1), [s1, s2), [s2, )+.
        #
        #   Example:
        #
        #   * Row keys := +["a", "apple", "custom", "customer_1", "customer_2",+
        #     +"other", "zz"]+
        #   * initial_split_keys := +["apple", "customer_1", "customer_2", "other"]+
        #   * Key assignment:
        #     * Tablet 1 +[, apple)                => {"a"}.+
        #       * Tablet 2 +[apple, customer_1)      => {"apple", "custom"}.+
        #       * Tablet 3 +[customer_1, customer_2) => {"customer_1"}.+
        #       * Tablet 4 +[customer_2, other)      => {"customer_2"}.+
        #       * Tablet 5 +[other, )                => {"other", "zz"}.+
        #   A hash of the same form as `Google::Bigtable::Admin::V2::CreateTableRequest::Split`
        #   can also be provided.
        # @return [Google::Bigtable::Admin::V2::Table]

        def create_table \
            instance_id,
            table_id,
            table,
            initial_splits: nil
          if initial_splits
            initial_splits = initial_splits.map { |key| { key: key } }
          end

          execute do
            tables.create_table(
              instance_path(instance_id),
              table_id,
              table,
              initial_splits: initial_splits
            )
          end
        end

        # Lists all tables served from a specified instance.
        #
        # @param instance_id [String]
        #   The unique Id of the instance for which tables should be listed.
        # @param view [Google::Bigtable::Admin::V2::Table::View]
        #   The view to be applied to the returned tables' fields.
        #   Defaults to +NAME_ONLY+ if unspecified; no others are currently supported.
        # @return [Google::Gax::PagedEnumerable<Google::Bigtable::Admin::V2::Table>]
        #   An enumerable of Google::Bigtable::Admin::V2::Table instances.
        #   See Google::Gax::PagedEnumerable documentation for other
        #   operations such as per-page iteration or access to the response

        def list_tables instance_id, view: nil
          execute do
            tables.list_tables(
              instance_path(instance_id),
              view: view
            )
          end
        end

        # Gets metadata information about the specified table.
        #
        # @param instance_id [String]
        #   The unique Id of the instance in which table is exists.
        # @param table_id [String]
        #   The unique Id of the requested table.
        # @param view [Google::Bigtable::Admin::V2::Table::View]
        #   The view to be applied to the returned table's fields.
        #   Defaults to +SCHEMA_VIEW+ if unspecified.
        # @return [Google::Bigtable::Admin::V2::Table]

        def get_table instance_id, table_id, view: nil
          execute do
            tables.get_table(
              table_path(instance_id, table_id),
              view: view
            )
          end
        end

        # Permanently deletes a specified table and all of its data.
        #
        # @param instance_id [String]
        #   The unique Id of the instance in which table is exists.
        # @param table_id [String]
        #   The unique Id of the table to be deleted.

        def delete_table instance_id, table_id
          execute do
            tables.delete_table(
              table_path(instance_id, table_id)
            )
          end
        end

        # Performs a series of column family modifications on the specified table.
        # Either all or none of the modifications will occur before this method
        # returns, but data requests received prior to that point may see a table
        # where only some modifications have taken effect.
        #
        # @param instance_id [String]
        #   The unique Id of the instance in which table is exists.
        # @param table_id [String]
        #   The unique Id of the table whose families should be modified.
        # @param modifications [Array<Google::Bigtable::Admin::V2::ModifyColumnFamiliesRequest::Modification | Hash>]
        #   Modifications to be atomically applied to the specified table's families.
        #   Entries are applied in order, meaning that earlier modifications can be
        #   masked by later ones (in the case of repeated updates to the same family,
        #   for example).
        #   A hash of the same form as `Google::Bigtable::Admin::V2::ModifyColumnFamiliesRequest::Modification`
        #   can also be provided.
        # @return [Google::Bigtable::Admin::V2::Table]

        def modify_column_families instance_id, table_id, modifications
          execute do
            tables.modify_column_families(
              table_path(instance_id, table_id),
              modifications
            )
          end
        end

        # Generates a consistency token for a Table, which can be used in
        # CheckConsistency to check whether mutations to the table that finished
        # before this call started have been replicated. The tokens will be available
        # for 90 days.
        #
        # @param instance_id [String]
        #   The unique Id of the instance in which table is exists.
        # @param table_id [String]
        #   The unique Id of the Table for which to create a consistency token.
        # @return [Google::Bigtable::Admin::V2::GenerateConsistencyTokenResponse]

        def generate_consistency_token instance_id, table_id
          execute do
            tables.generate_consistency_token(
              table_path(instance_id, table_id)
            )
          end
        end

        # Checks replication consistency based on a consistency token, that is, if
        # replication has caught up based on the conditions specified in the token
        # and the check request.
        #
        # @param instance_id [String]
        #   The unique Id of the instance in which table is exists.
        # @param table_id [String]
        #   The unique Id of the Table for which to check replication consistency.
        # @param token [String] Consistency token
        #   The token created using GenerateConsistencyToken for the Table.
        # @return [Google::Bigtable::Admin::V2::CheckConsistencyResponse]

        def check_consistency instance_id, table_id, token
          execute do
            tables.check_consistency(
              table_path(instance_id, table_id),
              token
            )
          end
        end

        # Permanently drop/delete a row range from a specified table. The request can
        # specify whether to delete all rows in a table, or only those that match a
        # particular prefix.
        #
        # @param instance_id [String]
        #   The unique Id of the instance in which table is exists.
        # @param table_id [String]
        #   The unique Id of the table on which to drop a range of rows.
        # @param row_key_prefix [String]
        #   Delete all rows that start with this row key prefix. Prefix cannot be
        #   zero length.
        # @param delete_all_data_from_table [true, false]
        #   Delete all rows in the table. Setting this to false is a no-op.
        # @param timeout [Integer]
        #   Set api call timeout if deadline exceeded exception.

        def drop_row_range \
             instance_id,
             table_id,
             row_key_prefix: nil,
             delete_all_data_from_table: nil,
             timeout: nil
          call_options = nil

          # Pass timeout with larger value if drop operation throw error for
          # tiemout time.
          if timeout
            retry_options = Google::Gax::RetryOptions.new(
              [],
              Google::Gax::BackoffSettings.new(0, 0, 0, timeout * 1000, 0, 0, 0)
            )
            call_options = Google::Gax::CallOptions.new(
              retry_options: retry_options
            )
          end

          execute do
            tables.drop_row_range(
              table_path(instance_id, table_id),
              row_key_prefix: row_key_prefix,
              delete_all_data_from_table: delete_all_data_from_table,
              options: call_options
            )
          end
        end

        # Creates an app profile within an instance.
        #
        # @param instance_id [String]
        #   The unique Id of the instance.
        # @param app_profile_id [String]
        #   The ID to be used when referring to the new app profile within its
        #   instance, e.g., +myprofile+
        # @param app_profile [Google::Bigtable::Admin::V2::AppProfile | Hash]
        #   The app profile to be created.
        #   Fields marked +OutputOnly+ will be ignored.
        #   A hash of the same form as `Google::Bigtable::Admin::V2::AppProfile`
        #   can also be provided.
        # @param ignore_warnings [Boolean]
        #   If true, ignore safety checks when creating the app profile.
        # @return [Google::Bigtable::Admin::V2::AppProfile]

        def create_app_profile \
            instance_id,
            app_profile_id,
            app_profile,
            ignore_warnings: nil
          execute do
            instances.create_app_profile(
              instance_path(instance_id),
              app_profile_id,
              app_profile,
              ignore_warnings: ignore_warnings
            )
          end
        end

        # Gets information about an app profile.
        #
        # @param instance_id [String]
        #   The unique Id of the instance.
        # @param app_profile_id [String]
        #   The unique Id of the requested app profile.
        # @return [Google::Bigtable::Admin::V2::AppProfile]

        def get_app_profile instance_id, app_profile_id
          execute do
            instances.get_app_profile(
              app_profile_path(instance_id, app_profile_id)
            )
          end
        end

        # Lists information about app profiles in an instance.
        #
        # @param instance_id [String]
        #   The unique Id of the instanc
        # @return [Google::Gax::PagedEnumerable<Google::Bigtable::Admin::V2::AppProfile>]
        #   An enumerable of Google::Bigtable::Admin::V2::AppProfile instances.
        #   See Google::Gax::PagedEnumerable documentation for other
        #   operations such as per-page iteration or access to the response
        #   object.
        def list_app_profiles instance_id
          execute do
            instances.list_app_profiles(
              instance_path(instance_id)
            )
          end
        end

        # Updates an app profile within an instance.
        #
        # @param app_profile [Google::Bigtable::Admin::V2::AppProfile | Hash]
        #   The app profile which will (partially) replace the current value.
        #   A hash of the same form as `Google::Bigtable::Admin::V2::AppProfile`
        #   can also be provided.
        # @param update_mask [Google::Protobuf::FieldMask | Hash]
        #   The subset of app profile fields which should be replaced.
        #   If unset, all fields will be replaced.
        #   A hash of the same form as `Google::Protobuf::FieldMask`
        #   can also be provided.
        # @param ignore_warnings [Boolean]
        #   If true, ignore safety checks when updating the app profile.
        # @return [Google::Longrunning::Operation]

        def update_app_profile app_profile, update_mask, ignore_warnings: nil
          execute do
            instances.update_app_profile(
              app_profile,
              update_mask,
              ignore_warnings: ignore_warnings
            )
          end
        end

        # Deletes an app profile from an instance.
        #
        # @param instance_id [String]
        #   The unique Id of the instance.
        # @param app_profile_id [String]
        #   The unique Id of the app profile to be deleted.
        # @param ignore_warnings [Boolean]
        #   If true, ignore safety checks when deleting the app profile.

        def delete_app_profile instance_id, app_profile_id, ignore_warnings: nil
          execute do
            instances.delete_app_profile(
              app_profile_path(instance_id, app_profile_id),
              ignore_warnings
            )
          end
        end

        # Gets the access control policy for an instance resource. Returns an empty
        # policy if an instance exists but does not have a policy set.
        #
        # @param instance_id [String]
        #   The unique Id of the instance for which the policy is being requested.
        # @return [Google::Iam::V1::Policy]

        def get_instance_policy instance_id
          execute do
            instances.get_iam_policy(
              instance_path(instance_id)
            )
          end
        end

        # Sets the access control policy on an instance resource. Replaces any
        # existing policy.
        #
        # @param instance_id [String]
        #   The unique Id of the instance for which the policy is being updated.
        # @param policy [Google::Iam::V1::Policy | Hash]
        #   REQUIRED: The complete policy to be applied to the +resource+. The size of
        #   the policy is limited to a few 10s of KB. An empty policy is a
        #   valid policy but certain Cloud Platform services (such as Projects)
        #   might reject them.
        #   A hash of the same form as `Google::Iam::V1::Policy`
        #   can also be provided.
        # @return [Google::Iam::V1::Policy]

        def set_instance_policy instance_id, policy
          execute do
            instances.set_iam_policy(
              instance_path(instance_id),
              policy
            )
          end
        end

        # Returns permissions that the caller has on the specified instance resource.
        #
        # @param instance_id [String]
        #   The instance Id of instance for which the policy detail is being requested.
        # @param permissions [Array<String>]
        #   The set of permissions to check for the +resource+. Permissions with
        #   wildcards (such as '*' or 'storage.*') are not allowed. For more
        #   information see
        #   [IAM Overview](https://cloud.google.com/iam/docs/overview#permissions).
        # @return [Google::Iam::V1::TestIamPermissionsResponse]

        def test_instance_permissions instance_id, permissions
          execute do
            instances.test_iam_permissions(
              instance_path(instance_id),
              permissions
            )
          end
        end

        # Execute api call and wrap errors to {Google::Cloud::Error}
        #
        # @raise [Google::Cloud::Error]

        def execute
          yield
        rescue Google::Gax::GaxError => e
          raise Google::Cloud::Error.from_error(e.cause)
        rescue GRPC::BadStatus => e
          raise Google::Cloud::Error.from_error(e)
        end

        # Create formatted project path
        #
        # @return [String]
        #   Formatted project path
        #   +projects/<project>+

        def project_path
          Admin::V2::BigtableInstanceAdminClient.project_path(project_id)
        end

        # Create formatted instance path
        #
        # @param instance_id [String]
        # @return [String]
        #   Formatted instance path
        #   +projects/<project>/instances/[a-z][a-z0-9\\-]+[a-z0-9]+.

        def instance_path instance_id
          Admin::V2::BigtableInstanceAdminClient.instance_path(
            project_id,
            instance_id
          )
        end

        # Create formatted cluster path
        #
        # @param instance_id [String]
        # @param cluster_id [String]
        # @return [String]
        #   Formatted cluster path
        #   +projects/<project>/instances/<instance>/clusters/<cluster>+.

        def cluster_path instance_id, cluster_id
          Admin::V2::BigtableInstanceAdminClient.cluster_path(
            project_id,
            instance_id,
            cluster_id
          )
        end

        # Create formatted location path
        #
        # @param location [String]
        #   zone name i.e us-east1-b
        # @return [String]
        #   Formatted location path
        #   +projects/<project_id>/locations/<location>+.

        def location_path location
          Admin::V2::BigtableInstanceAdminClient.location_path(
            project_id,
            location
          )
        end

        # Create formatted table path
        #
        # @param table_id [String]
        # @return [String]
        #   Formatted table path
        #   +projects/<project>/instances/<instance>/tables/<table>+

        def table_path instance_id, table_id
          Admin::V2::BigtableTableAdminClient.table_path(
            project_id,
            instance_id,
            table_id
          )
        end

        # Create formatted snapshot path
        #
        # @param instance_id [String]
        # @param cluster_id [String]
        # @param snapshot_id [String]
        # @return [String]
        #   Formatted snapshot path
        #   +projects/<project>/instances/<instance>/clusters/<cluster>/snapshots/<snapshot>+

        def snapshot_path instance_id, cluster_id, snapshot_id
          Admin::V2::BigtableTableAdminClient.snapshot_path(
            project_id,
            instance_id,
            cluster_id,
            snapshot_id
          )
        end

        # Create formatted app profile path
        #
        # @param instance_id [String]
        # @param app_profile_id [String]
        # @return [String]
        #   Formatted snapshot path
        #   +projects/<project>/instances/<instance>/appProfiles/<app_profile>+

        def app_profile_path instance_id, app_profile_id
          Admin::V2::BigtableInstanceAdminClient.app_profile_path(
            project_id,
            instance_id,
            app_profile_id
          )
        end

        # Inspect service object
        # @return [String]

        def inspect
          "#{self.class}(#{@project_id})"
        end
      end
    end
  end
end
