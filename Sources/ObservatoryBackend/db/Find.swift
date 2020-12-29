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
			var items = [Result]()
			var nItemsInResult = 1
			var offset = 0
			do {
				while nItemsInResult > 0 {
					let response = collection.find(
						query: findObject,
						skip: offset,
						limit: cursor.limit,
						batchSize: cursor.totalRecords
					)
					let currentItems = try processFullResponse(response!, makeItem: makeItem)
					offset += currentItems.count
					nItemsInResult = currentItems.count
					items += currentItems
				}
				return items
			} catch {
				throw error
			}
		} catch {
			throw error
		}
	}
}
