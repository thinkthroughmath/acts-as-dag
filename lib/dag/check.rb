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

    def check_for_missing_indirect_links_for_node(node)
      direct_ancestors = get_ancestors_for_node(node).to_a
      missing_ancestors = direct_ancestors - node.ancestors.flatten if node.ancestors.exists?
      missing_ancestors.map { |a| [a.id, node.id] unless a.nil? } unless missing_ancestors.nil?
    end

    def rgl_graph
      RGL::ImplicitGraph.new { |g|
        g.vertex_iterator { |b|
          Object.const_get(self.acts_as_dag_options[:node_class_name]).all.each &b
        }
        g.adjacent_iterator { |x, b|
          x.children.each { |a| b.call(a) }
        }
        g.directed = true
      }
    end

    def reverse_rgl_graph
      RGL::ImplicitGraph.new { |g|
        g.vertex_iterator { |b|
          Object.const_get(self.acts_as_dag_options[:node_class_name]).all.each &b
        }
        g.adjacent_iterator { |x, b|
          x.parents.each { |a| b.call(a) }
        }
        g.directed = true
      }
    end

    def get_ancestors_for_node(node)
      tree = reverse_rgl_graph.bfs_search_tree_from(node)
      reverse_rgl_graph.vertices_filtered_by { |v| tree.has_vertex? v unless v == node }
    end

    ## Check for wrong counts




  end
end

