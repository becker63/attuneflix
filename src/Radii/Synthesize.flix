pub mod Radii.Synthesize {
    /// Enumerates the normalized, well-sorted policy language up to `maxCost`.
    /// The catalog is indexed by the cost of the normalized expression, so
    /// aliases and inverse laws are canonicalized before consuming budget.
    pub def enumerate(maxCost: Int32): Set[Radii.Expr] =
        if (maxCost < 1) Set.empty()
        else collect(build(2, maxCost, Map#{1 => Radii.atoms()}))

    def build(cost: Int32, maxCost: Int32, catalog: Map[Int32, Set[Radii.Expr]]): Map[Int32, Set[Radii.Expr]] =
        if (cost > maxCost) catalog
        else {
            let reversed =
                at(cost - 1, catalog)
                |> Set.map(Radii.reverse)
                |> Set.filter(e -> Radii.cost(e) == cost);
            let binaries = binaryCosts(1, cost, catalog, Set.empty());
            let exact = Set.union(reversed, binaries);
            build(cost + 1, maxCost, Map.insert(cost, exact, catalog))
        }

    def binaryCosts(leftCost: Int32, totalCost: Int32, catalog: Map[Int32, Set[Radii.Expr]], acc: Set[Radii.Expr]): Set[Radii.Expr] =
        let rightCost = totalCost - leftCost - 1;
        if (rightCost < 1) acc
        else {
            let left = at(leftCost, catalog);
            let right = at(rightCost, catalog);
            let composed = Set.flatMap(x -> Set.filterMap(y -> Radii.compose(x, y), right), left);
            let united = Set.flatMap(x -> Set.filterMap(y -> Radii.union(x, y), right), left);
            binaryCosts(
                leftCost + 1,
                totalCost,
                catalog,
                Set.union(acc, Set.union(composed, united))
            )
        }

    def at(cost: Int32, catalog: Map[Int32, Set[Radii.Expr]]): Set[Radii.Expr] =
        Map.getWithDefault(cost, Set.empty(), catalog)

    def collect(catalog: Map[Int32, Set[Radii.Expr]]): Set[Radii.Expr] =
        Map.foldLeft(Set.union, Set.empty(), catalog)
}
