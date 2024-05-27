import moment from 'moment';
import { QueryTypes } from 'sequelize';
import { addWhereClause } from '@utils';
import { TIMESTAMP } from '@utils/constants';
import { getEarliestCreatedDate } from '@server/daos/purchasedProducts';
import { redis } from '@server/services/redis';
import { sendMessage } from '@server/services/slack';
import { logger } from '@server/utils';

export const handleAggregateQueries = (args, tableName) => {
  let where = ``;
  let join = ``;
  const addQuery = suffix => (tableName ? `${tableName}.` : '') + suffix;
  if (args?.startDate) {
    where = addWhereClause(where, `${addQuery(`created_at`)} > :startDate`);
  }
  if (args?.endDate) {
    where = addWhereClause(where, `${addQuery(`created_at`)} < :endDate`);
  }
  if (args?.category) {
    join = `LEFT JOIN products on products.id=purchased_products.product_id`;
    where = addWhereClause(where, `products.category = :category`);
  }
  return { where, join };
};
export const queryOptions = args => ({
  replacements: {
    type: QueryTypes.SELECT,
    startDate: moment(args?.startDate).format(TIMESTAMP),
    endDate: moment(args?.endDate).format(TIMESTAMP),
    category: args?.category
  },
  type: QueryTypes.SELECT
});

export const queryRedis = async (type, args) => {
  let startDate;
  let endDate;
  let count = 0;

  // Determine the start date
  if (!args?.startDate) {
    const createdAtDates = await getEarliestCreatedDate();
    startDate = moment(createdAtDates);
  } else {
    startDate = moment(args.startDate);
  }

  // Determine the end date
  if (!args?.endDate) {
    endDate = moment();
  } else {
    endDate = moment(args.endDate);
  }

  // Collect all keys to fetch in a single batch
  const keys = [];
  const currentDate = startDate.clone(); // Use clone to avoid mutating the original startDate
  while (currentDate.isSameOrBefore(endDate, 'day')) {
    const key = args?.category
      ? `${currentDate.format('YYYY-MM-DD')}_${args.category}`
      : `${currentDate.format('YYYY-MM-DD')}_total`;
    keys.push(key);
    currentDate.add(1, 'day');
  }

  // Batch fetch all keys
  const values = await redis.mget(keys);

  // Process the fetched values
  values.forEach((totalForDate, index) => {
    if (totalForDate) {
      try {
        const aggregateData = JSON.parse(totalForDate); // Parse JSON string
        count += Number(aggregateData[type]); // Aggregate the count for the specified type
      } catch (err) {
        const key = keys[index];
        sendMessage(`Error while parsing data for ${key} as got value ${totalForDate}`);
        logger().info(`Error while parsing data for ${key} as got value ${totalForDate}`);
      }
    }
  });

  console.log(`Final Count: ${count}`);
  return count;
};
