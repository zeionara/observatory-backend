import MongoDBStORM
import PerfectMongoDB
import StORM

public extension MongoDBStORM {
    func processFullResponse<Result>(_ response: MongoCursor, makeItem: () -> Result) throws -> [Result] where Result: MongoDBStORM {
		do {
			try results.rows = parseRows(response)
			results.cursorData.totalRecords = results.rows.count
            return (0..<results.rows.count).map{ i -> Result in
                let item = makeItem()
                item.to(self.results.rows[i])
                return item
            } 
		} catch {
			throw error
		}
	}

    func findAll<Result>(_ data: [String: Any], cursor: StORMCursor = StORMCursor(), makeItem: () -> Result) throws -> [Result] where Result: MongoDBStORM {
		do {
			let (collection, client) = try setupCollection()
            defer {
                close(collection, client)
            }
			let findObject = BSON(map: data)
			do {
				let response = collection.find(
					query: findObject,
					skip: cursor.offset,
					limit: cursor.limit,
					batchSize: cursor.totalRecords
				)
				return try processFullResponse(response!, makeItem: makeItem)
			} catch {
				throw error
			}
		} catch {
			throw error
		}
	}
}
