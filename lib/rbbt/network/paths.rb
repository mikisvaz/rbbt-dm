require 'priority_queue'
module Paths

  def self.dijkstra(adjacency, start_node, end_node = nil)
    return nil unless adjacency.include? start_node

    active = PriorityQueue.new         
    distances = Hash.new { 1.0 / 0.0 } 
    parents = Hash.new                 

    active[start_node] = 0
    best = 1.0 / 0.0
    until active.empty?
      u, distance = active.delete_min
      distances[u] = distance
      d = distance + 1
      adjacency[u].each do |v|
        next unless d < distances[v] and d < best # we can't relax this one
        active[v] = distances[v] = d
        parents[v] = u
        best = d if (String === end_node ? end_node == v : end_node.include?(v))
      end    
    end


    if end_node
      end_node = (end_node & parents.keys).first unless String === end_node
      return nil if not parents.include? end_node
      path = [end_node]
      while not path.last === start_node
        path << parents[path.last]
      end
      path
    else
      parents
    end
  end

  def self.weighted_dijkstra(adjacency, start_node, end_node = nil)
    return nil unless adjacency.include? start_node

    active = PriorityQueue.new         
    distances = Hash.new { 1.0 / 0.0 } 
    parents = Hash.new                 

    active[start_node] = 0
    best = 1.0 / 0.0
    until active.empty?
      u, distance = active.delete_min
      distances[u] = distance
      next if not adjacency.include?(u) or adjacency[u].nil? or adjacency[u].empty?
      Misc.zip_fields(adjacency[u]).each do |v,node_dist|
        d = distance + node_dist
        next unless d < distances[v] and d < best # we can't relax this one
        active[v] = distances[v] = d
        parents[v] = u
        best = d if (String === end_node ? end_node == v : end_node.include?(v))
      end    
    end

    if end_node
      end_node = (end_node & parents.keys).first unless String === end_node
      return nil if not parents.include? end_node
      path = [end_node]
      while not path.last === start_node
        path << parents[path.last]
      end
      path
    else
      parents
    end
  end

  def self.random_weighted_dijkstra(adjacency, l, start_node, end_node = nil)
    return nil unless adjacency.include? start_node

    active = PriorityQueue.new         
    distances = Hash.new { 1.0 / 0.0 } 
    parents = Hash.new                 

    active[start_node] = 0
    best = 1.0 / 0.0
    until active.empty?
      u, distance = active.delete_min
      distances[u] = distance
      next if not adjacency.include?(u) or adjacency[u].nil? or adjacency[u].empty?
      Misc.zip_fields(adjacency[u]).each do |v,node_dist|
        d = distance + (node_dist * (l + rand))
        next unless d < distances[v] and d < best # we can't relax this one
        active[v] = distances[v] = d
        parents[v] = u
        best = d if (String === end_node ? end_node == v : end_node.include?(v))
      end    
    end

    if end_node
      end_node = (end_node & parents.keys).first unless String === end_node
      return nil if not parents.include? end_node
      path = [end_node]
      while not path.last === start_node
        path << parents[path.last]
      end
      path
    else
      parents
    end
  end


end
