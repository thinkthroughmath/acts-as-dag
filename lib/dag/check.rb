require "rgl/implicit"
require "rgl/traversal"
require "rgl/topsort"

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
      tree.vertices - [node]
    end

    def get_path_count_from_node(from)
      tree = rgl_graph.bfs_search_tree_from(from)
      top = tree.topsort_iterator
      counts = Hash[ top.to_a.zip( Array.new(top.count) { 0 } ) ]
      counts[from] = 1

      top.each do |v|
        # get immediate children
        children = rgl_graph.edges_filtered_by { |source, sink| source == v && tree.has_vertex?(sink) }

        # set count for child = count for child + count for self
        children.each_edge do |parent, child|
          counts[child] += counts[parent]
        end
      end
      counts
    end

    def get_path_counts
      path_counts = Hash[rgl_graph.to_a.zip(Array.new(self.count))]

      nodes_checked = 0
      nodes_total = path_counts.count

      path_counts.each do |start, counts|
        path_counts[start] = get_path_count_from_node(start)
        nodes_checked += 1
        yield nodes_checked, nodes_total if block_given?
      end
      path_counts
    end

    def check_path_counts
      if block_given?
        # pass along our method to report progress...
        path_counts = get_path_counts &Proc.new
      else
        path_counts = get_path_counts
      end
      incorrect_path_counts = []
      self.all.each do |e|
        if e.count != path_counts[e.ancestor][e.descendant]
          incorrect_path_counts << { count_should_be: path_counts[e.ancestor][e.descendant], for_link: e }
        end
      end
      incorrect_path_counts
    end

  end
end

