require "rgl/implicit"
require "rgl/traversal"

module Dag
  module Check

    def link_count
      self.all.count
    end

    def edge_count
      self.direct.count
    end

    def node_count
      Object.const_get(self.acts_as_dag_options[:node_class_name]).all.count
    end

    def check_for_missing_indirect_links
      missing_indirect_links = []
      Object.const_get(self.acts_as_dag_options[:node_class_name]).all.each do |n|
        missing_links = check_for_missing_indirect_links_for_node n
        missing_links.each { |l| missing_indirect_links << l } unless missing_links.nil?
      end
      missing_indirect_links
    end

    def get_sql_to_heal_missing_indirect_links
      missing_indirect_links = check_for_missing_indirect_links
      sql_statements = []
      missing_indirect_links.each { |ml| sql_statements << heal_missing_indirect_link( *ml ) }
      sql_statements.join "\n"
    end

    def heal_missing_indirect_link(source, sink)
      # I was going to have this just execute the sql to fix the problem, but our sharding makes this rather
      # difficult...
          "
          INSERT INTO #{self.table_name}
            (#{self.acts_as_dag_options[:ancestor_id_column]},
             #{self.acts_as_dag_options[:descendant_id_column]},
             #{self.acts_as_dag_options[:direct_column]},
             #{self.acts_as_dag_options[:count_column]}
            ) VALUES (
             #{source},
             #{sink},
             'f',
             1 );"
    end

    def check_for_missing_indirect_links_for_node(node)
      direct_ancestors = get_ancestors_for_node(node).to_a
      missing_ancestors = direct_ancestors - node.ancestors.flatten if node.ancestors.exists?
      missing_ancestors.map { |a| [a.id, node.id] unless a.nil? } unless missing_ancestors.nil?
    end

    def rgl_graph
      @rgl_graph ||= RGL::ImplicitGraph.new { |g|
        g.vertex_iterator { |b|
          Object.const_get(self.acts_as_dag_options[:node_class_name]).all.each &b
        }
        g.adjacent_iterator { |x, b|
          x.children.each { |a| b.call(a) }
        }
        g.directed = true
      }
      @rgl_graph
    end

    def reverse_rgl_graph
      @reverse_rgl_graph ||= RGL::ImplicitGraph.new { |g|
        g.vertex_iterator { |b|
          Object.const_get(self.acts_as_dag_options[:node_class_name]).all.each &b
        }
        g.adjacent_iterator { |x, b|
          x.parents.each { |a| b.call(a) }
        }
        g.directed = true
      }
      @reverse_rgl_graph
    end

    def get_ancestors_for_node(node)
      tree = reverse_rgl_graph.bfs_search_tree_from(node)
      reverse_rgl_graph.vertices_filtered_by { |v| tree.has_vertex? v unless v == node }
    end

    ## Check for wrong counts


  end
end
